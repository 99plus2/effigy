module Effigy
  module Rails
    # Adds hooks to Rails to discover Effigy views and templates.
    #
    # View files should be added to the app/views/<controller> directory with
    # an .effigy suffix. Template files should be added to
    # app/templates/<controller> with no suffix.
    #
    # For example, the view and template for PostsController#new would be
    # app/views/posts/new.html.effigy and app/templates/posts/new.html,
    # respectively.
    #
    # You can use the packaged generators to create these files.
    #
    # See {Effigy::Rails} for more information about generators.
    class TemplateHandler < ActionView::TemplateHandler
      include ActionView::TemplateHandlers::Compilable

      # def self.call(template)
      #   p template.class
      #   p template
      #   new(template).compile
      # end

      # def initalize(view)
      #   super
      #   @view = view
      # end

      # Compiles the given view. Calls by ActionView when loading the view.
      # @return [String] Ruby code that can be evaluated to get the rendered
      #   contents of this view
      def compile(view)
        @view = view
        load_view_class
        return <<-RUBY
          assigns = {}
          if @controller
            variables = @controller.instance_variable_names
            variables -= @controller.protected_instance_variables if @controller.respond_to?(:protected_instance_variables)
            assigns = variables.inject({}) do |hash, name|
              hash.update(name => @controller.instance_variable_get(name))
            end
            if local_assigns
              local_assigns.each do |name, value|
                assigns.update("@\#{name}" => value)
              end
            end
          end
          view = #{view_class_name}.new(self, assigns) { |*names| yield(*names) }
          view.#{render_method}(#{template_source.inspect})
        RUBY
      end

      # Uses the name on the view for Rails 2, and guesses it from the
      # virtual path in Rails 3.
      #
      # @return [String] the name of the view, such as "index"
      def view_name
        if @view.respond_to?(:name)
          @view.name
        else
          @view.virtual_path.split('/').last
        end
      end

      # Uses the base_path on the view for Rails 2, and guesses it from the
      # virtual path in Rails 3.
      #
      # @return [String] the path from the view root to the view file. For
      #   example, "RAILS_ROOT/app/views/users/index.html.effigy" would be
      #   "users."
      def base_path
        if @view.respond_to?(:base_path)
          @view.base_path
        else
          # starts out like "users/index"
          @view.virtual_path.sub(%r{/[^/]*$}, '')
        end
      end

      # Loads the view class from the discovered view file. View classes should
      # be named after the controller and action, such as UsersIndexView.
      #
      # See {#view_class_name} for more information about class names.
      def load_view_class
        load(view_filename)
      end

      # Uses the Rails 2 filename or identifier in Rails 3.
      # @return [String] the filename for this view
      def view_filename
        if @view.respond_to?(:filename)
          @view.filename
        else
          @view.identifier
        end
      end

      # Generates a class name for this view. Normal views are prefixed with
      # the controller namd and suffixed with "View," such as "PostsEditView"
      # for app/views/posts/edit.html.effigy. Partials are prefixed with the
      # controller and suffixed with "Partial," such as "PostsPostPartial" for
      # app/views/posts/_post.html.effigy. Layouts are suffixed with "Layout,"
      # such as "ApplicationLayout" for
      # app/views/layouts/application.html.effigy.
      def view_class_name
        view_class_components.join('_').camelize.sub(/^Layouts/, '')
      end

      # @return [Array] the components that make up the class name for this view
      def view_class_components
        [base_path, view_name.sub(/^_/, ''), view_class_suffix]
      end

      # @return [String] the suffix for this view based on the type of view
      def view_class_suffix
        if layout?
          'layout'
        elsif partial?
          'partial'
        else
          'view'
        end
      end

      # @return [Boolean] true-ish if this view is a layout, false-ish otherwise
      def layout?
        base_path =~ /^layouts/
      end

      # @return [String] the method that should be used to render the document.
      # The template will be parsed as a full html document for a layout, and a
      # fragment for anything else.
      def render_method
        if layout?
          'render_html_document'
        else
          'render_html_fragment'
        end
      end

      # @return [Boolean] true-ish if this view is a partial, false-ish otherwise
      def partial?
        view_name =~ /^_/
      end

      # @return [String] the contents of the template file for this view
      def template_source
        template_path = view_load_path.sub(/\/views$/, '/templates')
        template_file_name = File.join(template_path, base_path, "#{view_name}.#{view_format}")
        IO.read(template_file_name)
      end

      # Uses the load path on the view for Rails 2, and guesses it based on the
      # identifier will work for Rails 3.
      #
      # @return [String] the load path from which this view was loaded
      def view_load_path
        if @view.respond_to?(:load_path)
          @view.load_path.path
        else
          @view.identifier.sub(%r{/#{Regexp.escape(@view.virtual_path)}.*$}, '')
        end
      end

      # @return [String] the format being rendered
      def view_format
        if @view.respond_to?(:format)
          @view.format
        else
          @view.formats.first
        end
      end
    end
  end
end
