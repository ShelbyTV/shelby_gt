# encoding: UTF-8

# Use our custom templates to render additional info for MongoMapper fields
# documented as methods
YARD::Templates::Engine.register_template_path 'lib/yard-mongomapper/templates/'

module YARD
  module MongoMapper
    class KeyHandler < YARD::Handlers::Ruby::DSLHandler
      handles method_call(:key)

      def process
        # First parameter to the key method is the name of the key,
        # create a method object with that name to document this, sort of like an accessor method
        key_name = statement.parameters.first.jump(:tstring_content, :ident).source.to_sym
        obj = CodeObjects::MethodObject.new(namespace, key_name, scope)
        register(obj)
        register_group(obj, "MongoMapper Fields")

        # we need some magic to attach the docstring comment if no tags were specified
        # by the user
        if obj.docstring == ""
          obj.docstring = statement.comments
        end

        # Second parameter to the key method is the type of the field
        # If we can find it, declare that as the return type for this method via a return tag
        field_type = statement.parameters[1]
        if type_name = field_type && field_type.jump(:const).source
          if return_tag = obj.tag(:return)
            return_tag.types ||= [type_name]
          else
            obj.add_tag(Tags::Tag.new(:return, nil, [type_name]))
          end
        end

        # If the options hash contains a key abbreviation,
        # store that on the method object for rendering later
        if options_hash_node = statement.parameters[2]
          options_hash_node.children.each do |child|
            key = child.jump(:ident).source
            if key == 'abbr'
              # strip off the leading ':' in the abbreviation
              obj['key_abbreviation'] = child.children[1].source[1..-1]
            end
          end
        end

      end
    end
  end
end