FactoryGirl.define do

  factory :invoice do
    customer_name "Example Customer Name"
    customer_email 'example@example.com'
    serie
    number 1
  end

  factory :invoice_random, class: Invoice do
    sequence(:customer_name, "A")  { |n| "John #{n}. Smith" }
    sequence(:customer_email, "a") { |n| "john.#{n}.smith@example.com" }

    # Find an existing series or generate a random one
    serie  { Serie.all.sample || generate(:serie_random) }
    number { serie.next_number }

    after(:create) do |invoice|
      # Items
      create_list(:item_random, rand(1..10), common: invoice)

      # Payments
      invoice.set_amounts

      max_payments = rand(1..4)
      paid_amount = invoice.gross_amount / max_payments

      # Decide whether to pay the entire invoice, part or none.
      max_payments -= rand(0..max_payments)

      if max_payments > 0
        create_list(:payment_random, max_payments, invoice: invoice,
                    amount: paid_amount)
      end

      # Update totals in db
      invoice.set_amounts!
    end
  end

end


