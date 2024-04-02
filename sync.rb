# frozen_string_literal: true

require 'erb'
require 'date'
require 'yaml'

class Customer
  attr_reader :key, :name, :address

  def initialize(key:, address: [])
    @key = key
    @address = address
    @name = address.first
  end
end

class Invoice
  attr_reader :id, :date, :due_period_days, :delivered_on, :customer, :content, :currency

  def initialize(id:, date:, delivered_on:, customer:, currency:, content: [], due_period_days: 30) # rubocop:disable Metrics/ParameterLists
    @id = id
    @date = date
    @due_period_days = due_period_days
    @delivered_on = delivered_on
    @customer = customer
    @content = content
    @currency = currency
  end

  def due_date
    date + due_period_days
  end

  def total
    content.inject(0) { |sum, il| sum + il.amount }
  end

  def vat_total
    content.inject(0) { |sum, il| sum + il.vat_amount }
  end

  def total_with_vat
    total + vat_total
  end

  def get_binding # rubocop:disable Naming/AccessorMethodName
    binding
  end
end

class InvoiceLine
  attr_reader :item, :quantity, :unit_price, :unit, :vat_percent

  def initialize(item:, quantity:, unit_price:, unit: 'tim', vat_percent: 25)
    @item = item
    @quantity = quantity
    @unit_price = unit_price
    @unit = unit
    @vat_percent = vat_percent
  end

  def amount
    unit_price * quantity
  end

  def vat_amount
    amount * vat_percent / 100
  end
end

class DB
  # Move to private
  attr_accessor :customers, :invoices, :data

  def initialize(source_path:)
    @customers = []
    @data = {}
    @invoices = []
    @source_path = source_path
  end

  def load! # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    self.data = YAML.load_file(
      source_path,
      permitted_classes: [Date]
    )
    data['customers'].each do |c|
      customers << Customer.new(key: c['key'], address: c['address_lines'])
    end

    data['invoices'].each_with_index do |invoice, i|
      content = invoice['content'].map do |il|
        InvoiceLine.new(
          item: il['item'],
          quantity: il['quantity'],
          unit_price: il['unit_price']
        )
      end
      invoices << Invoice.new(
        id: i + 1,
        customer: find_customer_by_key(key: invoice['customer_key']),
        date: invoice['invoice_date'],
        delivered_on: invoice['delivered_on'],
        content: content,
        currency: 'kr'
      )
    end
  end

  private

  attr_reader :source_path

  def find_customer_by_key(key:)
    customers.find { |c| c.key == key }
  end
end

db = DB.new(source_path: './db.yaml')
db.load!

invoice_template = ERB.new(
  File.read('./invoice.tex.erb'),
  trim_mode: '%>'
)

db.invoices.each do |i|
  filename = "#{i.date.to_s.gsub('-', '')}_#{i.customer.name.gsub(' ', '_')}.tex"
  f = File.new(filename, 'w')
  f.puts(invoice_template.result(i.get_binding))
  f.close
end
