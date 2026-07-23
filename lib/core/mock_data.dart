
class MockData {
  MockData._();

  static final List<Map<String, dynamic>> bnmHistoryData = [
    {'year': 1997, 'opr': 7.50, 'baseRate': 9.50, 'lendingRate': 11.50},
    {'year': 1998, 'opr': 9.50, 'baseRate': 11.00, 'lendingRate': 14.15},
    {'year': 1999, 'opr': 5.50, 'baseRate': 7.50, 'lendingRate': 8.60},
    {'year': 2000, 'opr': 5.50, 'baseRate': 6.79, 'lendingRate': 7.95},
    {'year': 2001, 'opr': 5.00, 'baseRate': 6.39, 'lendingRate': 7.45},
    {'year': 2002, 'opr': 4.50, 'baseRate': 6.00, 'lendingRate': 7.05},
    {'year': 2003, 'opr': 4.50, 'baseRate': 6.00, 'lendingRate': 7.00},
    {'year': 2004, 'opr': 4.50, 'baseRate': 5.98, 'lendingRate': 7.00},
    {'year': 2005, 'opr': 3.00, 'baseRate': 5.98, 'lendingRate': 7.00},
    {'year': 2006, 'opr': 3.50, 'baseRate': 6.72, 'lendingRate': 7.60},
    {'year': 2007, 'opr': 3.50, 'baseRate': 6.72, 'lendingRate': 7.60},
    {'year': 2008, 'opr': 3.25, 'baseRate': 6.72, 'lendingRate': 7.55},
    {'year': 2009, 'opr': 2.00, 'baseRate': 5.51, 'lendingRate': 6.27},
    {'year': 2010, 'opr': 2.75, 'baseRate': 6.27, 'lendingRate': 7.05},
    {'year': 2011, 'opr': 3.00, 'baseRate': 6.53, 'lendingRate': 7.35},
    {'year': 2012, 'opr': 3.00, 'baseRate': 6.53, 'lendingRate': 7.35},
    {'year': 2013, 'opr': 3.00, 'baseRate': 6.53, 'lendingRate': 7.35},
    {'year': 2014, 'opr': 3.25, 'baseRate': 6.70, 'lendingRate': 7.55},
    {'year': 2015, 'opr': 3.25, 'baseRate': 6.70, 'lendingRate': 7.55},
    {'year': 2016, 'opr': 3.00, 'baseRate': 6.65, 'lendingRate': 7.40},
    {'year': 2017, 'opr': 3.00, 'baseRate': 6.68, 'lendingRate': 7.44},
    {'year': 2018, 'opr': 3.25, 'baseRate': 6.91, 'lendingRate': 7.69},
    {'year': 2019, 'opr': 3.00, 'baseRate': 6.66, 'lendingRate': 7.44},
    {'year': 2020, 'opr': 1.75, 'baseRate': 5.41, 'lendingRate': 6.19},
    {'year': 2021, 'opr': 1.75, 'baseRate': 5.41, 'lendingRate': 6.19},
    {'year': 2022, 'opr': 2.75, 'baseRate': 6.41, 'lendingRate': 7.19},
    {'year': 2023, 'opr': 3.00, 'baseRate': 6.66, 'lendingRate': 7.44},
    {'year': 2024, 'opr': 3.00, 'baseRate': 6.66, 'lendingRate': 7.44},
    {'year': 2025, 'opr': 3.00, 'baseRate': 6.66, 'lendingRate': 7.44},
    {'year': 2026, 'opr': 2.75, 'baseRate': 6.41, 'lendingRate': 7.19},
  ];

  static Map<String, dynamic>? getDataByYear(int year) {
    try {
      return bnmHistoryData.firstWhere((e) => e['year'] == year);
    } catch (_) {
      return null;
    }
  }

  static const List<String> equipmentTypes = [
    'AI Vision Inspector',
    'Robotic Arm',
    'CNC Machine',
    'Automated Conveyor',
    '3D Printer (Industrial)',
    'Laser Cutter',
    'IoT Sensor Array',
    'Packaging Robot',
  ];
}
