require 'nokogiri'
require 'effigy/class_list'
require 'effigy/errors'
require 'effigy/selection'

module Effigy
  class View
    def text(selector, content)
      select(selector).content = content
    end

    def attr(selector, attributes_or_attribute_name, value = nil)
      element = select(selector)
      attributes = attributes_or_attribute_name.to_effigy_attributes(value)
      attributes.each do |attribute, value|
        element[attribute.to_s] = value
      end
    end

    def replace_each(selector, collection, &block)
      original_element = select(selector)
      collection.inject(original_element) do |sibling, item|
        item_element = clone_element_with_item(original_element, item, &block)
        sibling.add_next_sibling(item_element)
      end
      original_element.unlink
    end

    def render(template)
      @current_context = Nokogiri::XML.parse(template)
      yield if block_given?
      transform
      output
    end

    def remove(selector)
      select_all(selector).each { |element| element.unlink }
    end

    def add_class(selector, *class_names)
      element = select(selector)
      class_list = ClassList.new(element)
      class_names.each { |class_name| class_list << class_name }
    end

    def remove_class(selector, *class_names)
      element = select(selector)
      class_list = ClassList.new(element)
      class_names.each { |class_name| class_list.remove(class_name) }
    end

    def html(selector, xml)
      select(selector).inner_html = xml
    end

    def replace_with(selector, xml)
      select(selector).after(xml).unlink
    end

    def find(selector)
      if block_given?
        old_context = @current_context
        @current_context = select(selector)
        yield
        @current_context = old_context
      else
        Selection.new(self, selector)
      end
    end
    alias_method :f, :find

    private

    def transform
    end

    attr_reader :current_context

    def select(nodes)
      if nodes.respond_to?(:search)
        nodes
      else
        current_context.at(nodes) or
          raise ElementNotFound, nodes
      end
    end

    def select_all(selector)
      result = current_context.search(selector)
      raise ElementNotFound, selector if result.empty?
      result
    end

    def clone_element_with_item(original_element, item, &block)
      item_element = original_element.dup
      find(item_element) { yield(item) }
      item_element
    end

    def output
      current_context.to_xhtml
    end

  end
end
