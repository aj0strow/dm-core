module DataMapper
  module Associations
    module ManyToOne
      extend Assertions

      # Setup many to one relationship between two models
      # -
      # @private
      def self.setup(name, model, options = {})
        assert_kind_of 'name',    name,    Symbol
        assert_kind_of 'model',   model,   Resource::ClassMethods
        assert_kind_of 'options', options, Hash

        repository_name = model.repository.name

        model.class_eval <<-EOS, __FILE__, __LINE__
          def #{name}
            #{name}_association.nil? ? nil : #{name}_association
          end

          def #{name}=(parent)
            #{name}_association.replace(parent)
          end

          private

          def #{name}_association
            @#{name}_association ||= begin
              unless relationship = model.relationships(#{repository_name.inspect})[:#{name}]
                raise ArgumentError, 'Relationship #{name.inspect} does not exist'
              end
              association = Proxy.new(relationship, self)
              child_associations << association
              association
            end
          end
        EOS

        model.relationships(repository_name)[name] = Relationship.new(
          name,
          repository_name,
          model.name,
          options.fetch(:class_name, Extlib::Inflection.classify(name)),
          options
        )
      end

      class Proxy
        include Assertions

        instance_methods.each { |m| undef_method m unless %w[ __id__ __send__ class kind_of? respond_to? assert_kind_of should should_not ].include?(m) }

        def replace(parent)
          @parent = parent
          @relationship.attach_parent(@child, @parent)
          self
        end

        def save
          return false if @parent.nil?
          return true  unless parent.new_record?

          DataMapper.repository(@relationship.repository_name) do
            parent.save
          end
        end

        def reload
          replace(nil)
        end

        def kind_of?(klass)
          super || parent.kind_of?(klass)
        end

        def respond_to?(method, include_private = false)
          super || parent.respond_to?(method, include_private)
        end

        private

        def initialize(relationship, child)
          assert_kind_of 'relationship', relationship, Relationship
          assert_kind_of 'child',        child,        Resource

          @relationship = relationship
          @child        = child
        end

        def parent
          @parent ||= @relationship.get_parent(@child)
        end

        def method_missing(method, *args, &block)
          parent.__send__(method, *args, &block)
        end
      end # class Proxy
    end # module ManyToOne
  end # module Associations
end # module DataMapper
