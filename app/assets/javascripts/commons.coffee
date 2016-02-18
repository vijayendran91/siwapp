# Function to recalculate amounts
# Receives a controller name as string, and a form object to serialize, and
# retrieves the amounts from the server.
set_amounts = (controller_name, form) ->
  url = Routes[controller_name + '_amounts_path']() + '?' + form.serialize()
  $.get url, ->
    return

# Function to get amounts json and do anything with them via callback
# Receives a controller name as string, and a form object to serialize
# retrieves amounts in a json
get_amounts = (controller_name, form, callback) ->
  url = Routes[controller_name + '_amounts_path']() + '?' + form.serialize()
  $.ajax url: url, dataType: 'json', success: (data) ->
    return callback data

# Retrieves the common part of the id of all fields in a cocoon formset row
get_id_prefix = (input_field) ->
  id_prefix = input_field.attr('id')
  id_prefix = id_prefix.substring(0, id_prefix.lastIndexOf('_'))
  id_prefix

# Function to initialize autocomplete behavior on invoice-like items
# on load and when a new item is inserted.
init_invoice_item_autocomplete = (input_field) ->
  id_prefix = get_id_prefix input_field
  input_field.autocomplete source: '/invoices/autocomplete.json', select: (event, ui) ->
    $("##{id_prefix}_unitary_cost").val ui.item.unitary_cost
    $("##{id_prefix}_unitary_cost").trigger "change" # to trigger recalculations

# Function to deactivate autocomplete behavior on invoice-like items
# when they are removed.
destroy_invoice_item_autocomplete = (input_field) ->
  if input_field.data 'autocomplete'
    input_field.autocomplete 'destroy'
    input_field.removeData 'autocomplete'

# Works with Turbolinks thanks to:
# - http://github.com/kossnocorp/jquery.turbolinks
# - https://github.com/rails/turbolinks#jqueryturbolinks
jQuery(document).ready ($) ->

  # Find forms that behave like an invoice
  # Those forms have a data-controller attribute that contains the current
  # controller name and are matched also by a .js-invoice-like class.
  $('form.js-invoice-like[data-controller]').each ->
    # TODO(@carlos): If the form doesn't have the class and the data- attribute
    # it won't match. Maybe it will be better to be less restrictive and throw
    # an error to warn the developer.
    form = $(this)
    controller_name = form.data('controller')

    # Find sections that change the amounts of the invoice-like form
    form.find('[data-changes="amount"]')
      # When an item changes, update form amounts
      .on 'change', '.js-item', (e) ->
        item = $(e.target)
        if item.prop 'tagName' == 'TEXTAREA'
          return
        # Set the base amount of the item = quantity * unitary_cost
        # Attention: discounts and taxes are not calculated here!!
        # those are calculated only in the totals.
        item_row = item.parents('.js-item')
        item_row.find('.base-amount').val(
          item_row.find('.quantity').val() * item_row.find('.unitary-cost').val()
        )
        # Set total amounts of invoice
        set_amounts(controller_name, form)
      # When an item is removed, update form amounts
      .on 'cocoon:after-remove', (e, item) ->
        set_amounts(controller_name, form)

    # Find invoice items and init autocomplete
    form.find(".item-description").each () ->
      init_invoice_item_autocomplete $(this)

    # Set defaults when adding something dynamic to the form with cocoon
    form.on 'cocoon:after-insert', (e, item) ->
      if item.hasClass 'js-payment'
        # default amount is what's unpaid
        amount_item = item.find 'input[name*=amount]'
        get_amounts controller_name, form, (data) ->
          amount = data.gross_amount - data.paid_amount
          amount = if amount > 0 then amount else 0
          amount_item.val amount
          return
        # default date is today
        date_item = item.find 'input[name*=date]'
        date_item.val (new Date).toISOString().substr 0, 10
      else if item.hasClass 'js-item'
        init_invoice_item_autocomplete item.find('.item-description')

    # Execute actions when something dynamic is removed from the form
    # with cocoon
    form.on 'cocoon:before-remove', (e, item) ->
      if item.hasClass 'js-item'
        destroy_invoice_item_autocomplete item

    # Set the autocomplete for customer selection
    model = form.data('model')
    $("##{model}_name").autocomplete {
      source: '/customers/autocomplete.json',
      select: (event, ui) ->
        # Once the customer is selected autofill fields:
        $("##{model}_customer_id").val ui.item.id
        $("##{model}_identification").val ui.item.identification
        $("##{model}_email").val ui.item.email
        $("##{model}_contact_person").val ui.item.contact_person
        $("##{model}_invoicing_address").val ui.item.invoicing_address
        $("##{model}_shipping_address").val ui.item.shipping_address
    }
