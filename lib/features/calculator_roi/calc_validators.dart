String? validateEquipmentPrice(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Equipment price is required.';
  if (!RegExp(r'^[0-9]+\.[0-9]{2}$').hasMatch(text)) {
    return 'Enter price in RM format (e.g. 5000.00).';
  }
  final cents = int.tryParse(text.replaceAll('.', ''));
  if (cents == null) return 'Enter price in RM format (e.g. 5000.00).';
  if (cents < 500000) return 'Minimum equipment price is RM 5,000.00.';
  if (cents > 60000000) return 'Maximum equipment price is RM 600,000.00.';
  return null;
}

String? validateEquipmentQuantity(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Quantity is required.';
  if (!RegExp(r'^[0-9]+$').hasMatch(text)) {
    return 'Enter a whole number from 1 to 999.';
  }
  final quantity = int.tryParse(text);
  if (quantity == null || quantity > 999) return 'Maximum quantity is 999.';
  if (quantity < 1) return 'Minimum quantity is 1.';
  return null;
}
