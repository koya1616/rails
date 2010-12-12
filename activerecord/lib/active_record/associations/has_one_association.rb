module ActiveRecord
  # = Active Record Belongs To Has One Association
  module Associations
    class HasOneAssociation < AssociationProxy #:nodoc:
      def create(attrs = {}, replace_existing = true)
        new_record(replace_existing) do |reflection|
          attrs = merge_with_conditions(attrs)
          reflection.create_association(attrs)
        end
      end

      def create!(attrs = {}, replace_existing = true)
        new_record(replace_existing) do |reflection|
          attrs = merge_with_conditions(attrs)
          reflection.create_association!(attrs)
        end
      end

      def build(attrs = {}, replace_existing = true)
        new_record(replace_existing) do |reflection|
          attrs = merge_with_conditions(attrs)
          reflection.build_association(attrs)
        end
      end

      def replace(obj, dont_save = false)
        load_target

        unless @target.nil? || @target == obj
          if dependent? && !dont_save
            case @reflection.options[:dependent]
            when :delete
              @target.delete if @target.persisted?
              @owner.clear_association_cache
            when :destroy
              @target.destroy if @target.persisted?
              @owner.clear_association_cache
            when :nullify
              @target[@reflection.primary_key_name] = nil
              @target.save if @owner.persisted? && @target.persisted?
            end
          else
            @target[@reflection.primary_key_name] = nil
            @target.save if @owner.persisted? && @target.persisted?
          end
        end

        if obj.nil?
          @target = nil
        else
          raise_on_type_mismatch(obj)
          set_belongs_to_association_for(obj)
          @target = (AssociationProxy === obj ? obj.target : obj)
        end

        set_inverse_instance(obj, @owner)
        @loaded = true

        unless !@owner.persisted? || obj.nil? || dont_save
          return (obj.save ? self : false)
        else
          return (obj.nil? ? nil : self)
        end
      end

      protected
        def owner_quoted_id(reflection = @reflection)
          if reflection.options[:primary_key]
            @owner.class.quote_value(@owner.send(reflection.options[:primary_key]))
          else
            @owner.quoted_id
          end
        end

      private
        def find_target
          options = @reflection.options.dup.slice(:select, :order, :include, :readonly)

          the_target = with_scope(:find => @scope[:find]) do
            @reflection.klass.find(:first, options)
          end
          set_inverse_instance(the_target, @owner)
          the_target
        end

        def construct_find_scope
          if @reflection.options[:as]
            sql =
              "#{@reflection.quoted_table_name}.#{@reflection.options[:as]}_id = #{owner_quoted_id} AND " +
              "#{@reflection.quoted_table_name}.#{@reflection.options[:as]}_type = #{@owner.class.quote_value(@owner.class.base_class.name.to_s)}"
          else
            sql = "#{@reflection.quoted_table_name}.#{@reflection.primary_key_name} = #{owner_quoted_id}"
          end
          sql << " AND (#{conditions})" if conditions
          { :conditions => sql }
        end

        def construct_create_scope
          create_scoping = {}
          set_belongs_to_association_for(create_scoping)
          create_scoping
        end

        def new_record(replace_existing)
          # Make sure we load the target first, if we plan on replacing the existing
          # instance. Otherwise, if the target has not previously been loaded
          # elsewhere, the instance we create will get orphaned.
          load_target if replace_existing
          record = @reflection.klass.send(:with_scope, :create => @scope[:create]) do
            yield @reflection
          end

          if replace_existing
            replace(record, true)
          else
            record[@reflection.primary_key_name] = @owner.id if @owner.persisted?
            self.target = record
            set_inverse_instance(record, @owner)
          end

          record
        end

        def we_can_set_the_inverse_on_this?(record)
          inverse = @reflection.inverse_of
          return !inverse.nil?
        end

        def merge_with_conditions(attrs={})
          attrs ||= {}
          attrs.update(@reflection.options[:conditions]) if @reflection.options[:conditions].is_a?(Hash)
          attrs
        end
    end
  end
end
