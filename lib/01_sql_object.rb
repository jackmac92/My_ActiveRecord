require_relative 'db_connection'
require 'active_support/inflector'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    return @columns if @columns
    result = DBConnection.execute2(<<-SQL)
      SELECT
        *
      FROM
        #{self.table_name}
    SQL
    @columns = result[0].map(&:to_sym)
    @columns
  end

  def self.finalize!
    self.columns.each do |attr|
      define_method(attr) do
        self.attributes[attr]
      end
    end
    self.columns.each do |attr|
      define_method(attr.to_s+"=") do |val|
        self.attributes[attr] = val
      end
    end

  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name ||= name.tableize
  end

  def self.all
    result = DBConnection.execute2(<<-SQL)
      SELECT
        *
      FROM
        #{self.table_name}
    SQL
    self.parse_all(result[1..-1])
  end

  def self.parse_all(results)
    results.map do |instance_params|
      puts instance_params
      self.new(instance_params)
    end
  end

  def self.find(id)
    result = DBConnection.execute2(<<-SQL, id)
      SELECT
        *
      FROM
        #{self.table_name}
      WHERE
        #{self.table_name}.id = ?
    SQL
    return nil if result.count == 1
    self.new result[1]
  end

  def initialize(params = {})
    params.each do |k,v|
      begin
        self.send(k.to_s+"=",v)
      rescue NoMethodError => e
        raise "unknown attribute '#{k}'"
      end
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    # Don't think I Should do it this way # @attributes.map { |atr,val| val }
    self.class.columns.map do |col_name|
      self.send(col_name)
    end    

  end

  def insert
    col_names = self.class.columns.join(', ')
    question_marks = (["?"] * self.class.columns.count).join(', ')

    result = DBConnection.execute2(<<-SQL, *self.attribute_values)
      INSERT INTO
        #{self.class.table_name} (#{col_names})
      VALUES
        (#{question_marks})
    SQL
    id = DBConnection.last_insert_row_id
    self.send(:id=, id)
  end

  def update
    set_line = self.class.columns.map do |col|
      next if col.to_s == 'id'
      "#{col} = ?"
    end.compact.join(', ')
    update_attrs = self.attribute_values[1..-1]
    result = DBConnection.execute2(<<-SQL, *update_attrs, self.id)
      UPDATE
        #{self.class.table_name}
      SET
        #{set_line}
      WHERE
        id = ?
    SQL
    
  end

  def save
    self.id ? update : insert
  end
end
