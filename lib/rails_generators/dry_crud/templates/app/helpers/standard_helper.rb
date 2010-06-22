# A view helper to standartize often used functions like formatting, 
# tables, forms or action links. This helper is ideally defined in the 
# ApplicationController.
module StandardHelper
  
  NO_LIST_ENTRIES_MESSAGE = "No entries available"
  CONFIRM_DELETE_MESSAGE  = 'Do you really want to delete this entry?'
  
  FLOAT_FORMAT = "%.2f"
  TIME_FORMAT  = "%H:%M"
  EMPTY_STRING = "&nbsp;"   # non-breaking space asserts better css styling.
  
  ################  FORMATTING HELPERS  ##################################

  # Define an array of associations symbols in your helper that should not get automatically linked.
  #def no_assoc_links = [:city]
  
  # Formats a single value
  def f(value)
    case value
      when Fixnum then number_with_delimiter(value)
      when Float  then FLOAT_FORMAT % value
			when Date	  then value.to_s
      when Time   then value.strftime(TIME_FORMAT)   
      when true   then 'yes'
      when false  then 'no'
      when nil    then EMPTY_STRING
    else 
      value.respond_to?(:label) ? h(value.label) : h(value.to_s)
    end
  end
  
  # Formats an arbitrary attribute of the given ActiveRecord object.
  # If no specific format_{attr} method is found, formats the value as follows:
  # If the value is an associated model, renders the label of this object.
  # Otherwise, calls format_type.
  def format_attr(obj, attr)
    format_attr_method = :"format_#{attr.to_s}"
    if respond_to?(format_attr_method)
      send(format_attr_method, obj)
    elsif assoc = belongs_to_association(obj, attr)
      format_assoc(obj, assoc)
    else
      format_type(obj, attr)
    end
  end
  
  # Formats an active record association
  def format_assoc(obj, assoc)
    if assoc_val = obj.send(assoc.name)
      link_to_unless(no_assoc_link?(assoc), h(assoc_val.label), assoc_val)
    else
			'(none)'
    end
  end
  
  # Returns true if no link should be created when formatting the given association.
  def no_assoc_link?(assoc)
    (respond_to?(:no_assoc_links) && no_assoc_links.to_a.include?(assoc.name.to_sym)) || 
    !respond_to?("#{assoc.klass.name.underscore}_path".to_sym)
  end
  
  # Formats an arbitrary attribute of the given object depending on its data type.
  # For ActiveRecords, take the defined data type into account for special types
  # that have no own object class.
  def format_type(obj, attr)
    val = obj.send(attr)
    return EMPTY_STRING if val.nil?
    case column_type(obj, attr)
      when :time    then val.strftime(TIME_FORMAT)
      when :date    then val.to_date.to_s
      when :text    then simple_format(h(val))
      when :decimal then f(val.to_s.to_f)
    else f(val)
    end
  end
  
  # Returns the ActiveRecord column type or nil.
  def column_type(obj, attr)
    column_property(obj, attr, :type)
  end
  
  # Returns an ActiveRecord column property for the passed attr or nil
  def column_property(obj, attr, property)
    if obj.respond_to?(:column_for_attribute)
      column = obj.column_for_attribute(attr)
      column.try(property)
    end  
  end
  
  # Returns the :belongs_to association for the given attribute or nil if there is none.
  def belongs_to_association(obj, attr)
    if assoc = association(obj, attr)
      assoc if assoc.macro == :belongs_to
    end
  end
  
  # Returns the association proxy for the given attribute. The attr parameter
  # may be the _id column or the association name. Returns nil if no association
  # was found.
  def association(obj, attr)
    if obj.class.respond_to?(:reflect_on_association)
      assoc = attr.to_s =~ /_id$/ ? attr.to_s[0..-4].to_sym : attr
      obj.class.reflect_on_association(assoc)
    end
  end
  
  
  ##############  STANDARD HTML SECTIONS  ############################
  
  
  # Renders an arbitrary content with the given label. Used for uniform presentation.
  # Without block, this may be used in the form <%= labeled(...) %>, with like <% labeled(..) do %>
  def labeled(label, content = nil, &block)
    content = with_output_buffer(&block) if block_given?
    render(:partial => 'shared/labeled', :locals => { :label => label, :content => content}) 
  end
  
  # Transform the given text into a form as used by labels or table headers.
  def captionize(text, clazz = nil)
    if clazz.respond_to?(:human_attribute_name)
      clazz.human_attribute_name(text)
    else
      text.to_s.humanize.titleize      
    end
  end
  
  # Renders a list of attributes with label and value for a given object. 
  # Optionally surrounded with a div.
  def render_attrs(obj, attrs, div = true)
    html = attrs.collect do |a| 
      labeled(captionize(a, obj.class), format_attr(obj, a))
    end.join
    
    div ? content_tag(:div, html, :class => 'attributes') : html
  end
  
  # Renders a table for the given entries as defined by the following block.
  # If entries are empty, an appropriate message is rendered.
  def table(entries, &block)
    if entries.present?
      StandardTableBuilder.table(entries, self, &block)
    else
      content_tag(:div, NO_LIST_ENTRIES_MESSAGE, :class => 'list')
    end
  end
  
  # Renders a generic form for all given attributes using StandardFormBuilder.
  # Before the input fields, the error messages are rendered, if present.
  # The form is rendered with a basic save button.
  # If a block is given, custom input fields may be rendered and attrs is ignored.
  #
  # The form is always directly printed into the erb, so the call must
  # go within a normal <% form(...) %> section, not in a <%= output section
  def standard_form(object, attrs = [], options = {})
    form_for(object, {:builder => StandardFormBuilder}.merge(options)) do |form|
      concat render(:partial => 'shared/error_messages', :locals => {:errors => object.errors})
      
      if block_given? 
        yield(form)
      else
        concat form.labeled_input_fields(*attrs)
      end
      
      concat labeled(EMPTY_STRING, form.submit("Save"))
    end
  end
  
  # Alternate table row
  def tr_alt(&block)
    content_tag(:tr, :class => cycle("even", "odd", :name => "row_class"), &block)
  end
 
  
  ######## ACTION LINKS ###################################################### :nodoc:
  
  # Standard link action to the show page of a given record.
  def link_action_show(record)
    link_action 'Show', record
  end
  
  # Standard link action to the edit page of a given record.
  def link_action_edit(record)
    link_action 'Edit', edit_polymorphic_path(record)
  end
  
  # Standard link action to the destroy action of a given record.
  def link_action_destroy(record)
    link_action 'Delete', record, :confirm => CONFIRM_DELETE_MESSAGE, :method => :delete
  end
  
  # Standard link action to the list page.
  def link_action_index(url_options = {:action => 'index'})
    link_action 'List', url_options
  end
  
  # Standard link action to the new page.
  def link_action_add(url_options = {:action => 'new'})
    link_action 'Add', url_options
  end
  
  # A generic helper method to create action links.
  # These link may be styled to look like buttons, for example.
  def link_action(label, options = {}, html_options = {})
    link_to("[#{label}]", options, {:class => 'action'}.merge(html_options))
  end
  
end