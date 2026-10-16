/// Centralized user-facing strings catalog for Tindahan.
/// Ready for full Tagalog / Filipino localization in future releases.
class AppStrings {
  AppStrings._();

  // Navigation Tabs
  static const String navHome = 'Home';
  static const String navSell = 'Sell';
  static const String navProducts = 'Products';
  static const String navUtang = 'Utang';
  static const String navReports = 'Reports';
  static const String navSettings = 'Settings';

  // Home Dashboard
  static const String greetingMorning = 'Magandang Umaga!';
  static const String greetingAfternoon = 'Magandang Hapon!';
  static const String greetingEvening = 'Magandang Gabi!';
  static const String todaySales = "Today's Sales";
  static const String estProfit = 'Estimated Profit';
  static const String itemsSold = 'Items Sold';
  static const String totalUtang = 'Total Utang';
  static const String lowStockAlerts = 'Low Stock Items';
  static const String quickActions = 'Quick Actions';
  static const String salesTrends7d = 'Last 7 Days Sales';
  static const String actionNewSale = 'New Sale';
  static const String actionAddProduct = 'Add Product';
  static const String actionScanBarcode = 'Scan Barcode';
  static const String actionRecordPayment = 'Record Utang';

  // Point of Sale (Sell)
  static const String searchProductsHint = 'Search product or brand...';
  static const String scanBarcode = 'Scan Barcode';
  static const String cartTitle = 'Current Cart';
  static const String cartEmpty = 'No items in cart yet';
  static const String cartEmptyPrompt = 'Tap products on the grid to add to cart';
  static const String total = 'Total';
  static const String charge = 'Charge';
  static const String paymentTitle = 'Select Payment Method';
  static const String paymentCash = 'Cash';
  static const String paymentUtang = 'Utang (Credit)';
  static const String exactAmount = 'Exact';
  static const String cashTendered = 'Cash Received';
  static const String change = 'Change';
  static const String chooseCustomer = 'Select Customer for Utang';
  static const String confirmSale = 'Complete Sale';
  static const String saleSuccess = 'Sale Completed!';
  static const String insufficientCash = 'Cash received is less than total';
  static const String outOfStockWarning = 'Not enough stock available!';

  // Products & Inventory
  static const String productsTitle = 'Inventory';
  static const String allCategories = 'All';
  static const String filterLowStock = 'Low Stock Only';
  static const String inStock = 'in stock';
  static const String outOfStock = 'Out of Stock';
  static const String restock = 'Restock';
  static const String editProduct = 'Edit Product';
  static const String addProduct = 'New Product';
  static const String productName = 'Product Name';
  static const String productPrice = 'Selling Price (₱)';
  static const String productCost = 'Cost Price (₱)';
  static const String productStock = 'Current Stock';
  static const String lowStockThreshold = 'Low Stock Threshold';
  static const String category = 'Category';
  static const String barcode = 'Barcode';
  static const String piecesPerPack = 'Pieces per Pack (Tingi)';

  // Utang (Customer Credit)
  static const String utangTitle = 'Utang Ledger';
  static const String totalReceivables = 'Total Collectible';
  static const String searchCustomerHint = 'Search customer by name or alias...';
  static const String addCustomer = 'New Customer';
  static const String customerName = 'Customer Name';
  static const String customerNickname = 'Alias / Nickname';
  static const String customerPhone = 'Phone Number (Optional)';
  static const String customerLimit = 'Credit Limit (₱)';
  static const String recordPayment = 'Pay Utang';
  static const String shareStatement = 'Share Statement';
  static const String riskLow = 'Good Standing';
  static const String riskMedium = 'Moderate Risk';
  static const String riskHigh = 'High Risk';
  static const String riskNew = 'New Customer';

  // Reports
  static const String reportsTitle = 'Store Reports';
  static const String tabDay = 'Today';
  static const String tabWeek = 'This Week';
  static const String tabMonth = 'This Month';
  static const String grossRevenue = 'Gross Sales';
  static const String netProfit = 'Net Profit';
  static const String topSellers = 'Top 5 Best Sellers';
  static const String unpaidCredit = 'Outstanding Credit';

  // Common & Buttons
  static const String save = 'Save';
  static const String cancel = 'Cancel';
  static const String confirm = 'Confirm';
  static const String delete = 'Delete';
  static const String undo = 'Undo';
  static const String close = 'Close';
}
