<% if @equipment.errors.any? %>
  $('.jEquipmentForm .alert.alert-danger').remove()
  $('.jEquipmentForm').prepend('<div class="alert alert-danger"><%= @equipment.errors.full_messages.join(', ') %></div>')
  $('.modal-body').scrollTop(0)
<% else %>
  html = "<%= j render('health/durable_equipments/equipment_row', equipment: @equipment) %>"
  $('.jEquipmentList [data-id="<%= @equipment.id %>"]').replaceWith(html)
  $('.modal:visible .close').trigger('click')

<% end %>