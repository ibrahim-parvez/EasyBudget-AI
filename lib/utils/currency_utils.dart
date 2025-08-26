class CurrencyUtils {
  static const Map<String, String> _currencySymbols = {
    'AED': 'د.إ', // UAE Dirham
    'AFN': '؋',   // Afghani
    'ALL': 'L',   // Lek
    'AMD': '֏',   // Dram
    'ANG': 'ƒ',   // Netherlands Antillean Guilder
    'AOA': 'Kz',  // Kwanza
    'ARS': r'$',  // Argentine Peso
    'AUD': r'A$', // Australian Dollar
    'AWG': 'ƒ',   // Aruban Florin
    'AZN': '₼',   // Azerbaijan Manat
    'BAM': 'KM',  // Convertible Mark
    'BBD': r'Bds$', // Barbados Dollar
    'BDT': '৳',   // Taka
    'BGN': 'лв',  // Lev
    'BHD': '.د.ب', // Bahraini Dinar
    'BIF': 'FBu', // Burundi Franc
    'BMD': r'BD$', // Bermudian Dollar
    'BND': r'B$', // Brunei Dollar
    'BOB': 'Bs.', // Boliviano
    'BRL': 'R\$',  // Brazilian Real
    'BSD': r'B$', // Bahamian Dollar
    'BTN': 'Nu.', // Ngultrum
    'BWP': 'P',   // Pula
    'BYN': 'Br',  // Belarusian Ruble
    'BZD': r'BZ$', // Belize Dollar
    'CAD': r'C$', // Canadian Dollar
    'CDF': 'FC',  // Congolese Franc
    'CHF': 'CHF', // Swiss Franc
    'CLP': r'CLP$', // Chilean Peso
    'CNY': '¥',   // Yuan Renminbi
    'COP': r'COL$', // Colombian Peso
    'CRC': '₡',   // Costa Rican Colón
    'CUP': '₱',   // Cuban Peso
    'CVE': '\$',   // Cabo Verde Escudo
    'CZK': 'Kč',  // Czech Koruna
    'DJF': 'Fdj', // Djibouti Franc
    'DKK': 'kr',  // Danish Krone
    'DOP': 'RD\$', // Dominican Peso
    'DZD': 'دج',  // Algerian Dinar
    'EGP': '£',   // Egyptian Pound
    'ERN': 'Nkf', // Nakfa
    'ETB': 'Br',  // Ethiopian Birr
    'EUR': '€',   // Euro
    'FJD': r'FJ$', // Fiji Dollar
    'FKP': '£',   // Falkland Islands Pound
    'FOK': 'kr',  // Faroese Króna
    'GBP': '£',   // Pound Sterling
    'GEL': '₾',   // Lari
    'GHS': '₵',   // Cedi
    'GIP': '£',   // Gibraltar Pound
    'GMD': 'D',   // Dalasi
    'GNF': 'FG',  // Guinean Franc
    'GTQ': 'Q',   // Quetzal
    'GYD': r'GY$', // Guyana Dollar
    'HKD': r'HK$', // Hong Kong Dollar
    'HNL': 'L',   // Lempira
    'HRK': 'kn',  // Kuna
    'HTG': 'G',   // Gourde
    'HUF': 'Ft',  // Forint
    'IDR': 'Rp',  // Rupiah
    'ILS': '₪',   // New Israeli Shekel
    'INR': '₹',   // Indian Rupee
    'IQD': 'ع.د', // Iraqi Dinar
    'IRR': '﷼',  // Iranian Rial
    'ISK': 'kr',  // Iceland Krona
    'JMD': r'J$', // Jamaican Dollar
    'JOD': 'د.ا', // Jordanian Dinar
    'JPY': '¥',   // Yen
    'KES': 'KSh', // Kenyan Shilling
    'KGS': 'сом', // Som
    'KHR': '៛',   // Riel
    'KMF': 'CF',  // Comorian Franc
    'KRW': '₩',   // Won
    'KWD': 'د.ك', // Kuwaiti Dinar
    'KYD': r'KY$', // Cayman Islands Dollar
    'KZT': '₸',   // Tenge
    'LAK': '₭',   // Kip
    'LBP': 'ل.ل', // Lebanese Pound
    'LKR': 'Rs',  // Sri Lanka Rupee
    'LRD': r'LR$', // Liberian Dollar
    'LSL': 'L',   // Loti
    'LYD': 'ل.د', // Libyan Dinar
    'MAD': 'DH',  // Moroccan Dirham
    'MDL': 'L',   // Moldovan Leu
    'MGA': 'Ar',  // Ariary
    'MKD': 'ден', // Denar
    'MMK': 'K',   // Kyat
    'MNT': '₮',   // Tugrik
    'MOP': 'P',   // Pataca
    'MRU': 'UM',  // Ouguiya
    'MUR': '₨',   // Mauritius Rupee
    'MVR': 'Rf',  // Rufiyaa
    'MWK': 'MK',  // Malawi Kwacha
    'MXN': r'MXN$', // Mexican Peso
    'MYR': 'RM',  // Malaysian Ringgit
    'MZN': 'MT',  // Mozambique Metical
    'NAD': r'N$', // Namibia Dollar
    'NGN': '₦',   // Naira
    'NIO': 'C\$',  // Córdoba
    'NOK': 'kr',  // Norwegian Krone
    'NPR': '₨',   // Nepalese Rupee
    'NZD': r'NZ$', // New Zealand Dollar
    'OMR': 'ر.ع.', // Rial Omani
    'PAB': 'B/.', // Balboa
    'PEN': 'S/',  // Sol
    'PGK': 'K',   // Kina
    'PHP': '₱',   // Philippine Peso
    'PKR': '₨',   // Pakistan Rupee
    'PLN': 'zł',  // Zloty
    'PYG': '₲',   // Guarani
    'QAR': 'ر.ق', // Qatari Rial
    'RON': 'lei', // Romanian Leu
    'RSD': 'дин.', // Serbian Dinar
    'RUB': '₽',   // Russian Ruble
    'RWF': 'FRw', // Rwanda Franc
    'SAR': '﷼',  // Saudi Riyal
    'SBD': r'SBD$', // Solomon Islands Dollar
    'SCR': '₨',  // Seychelles Rupee
    'SDG': 'ج.س.', // Sudanese Pound
    'SEK': 'kr',  // Swedish Krona
    'SGD': r'S$', // Singapore Dollar
    'SHP': '£',   // Saint Helena Pound
    'SLL': 'Le',  // Leone
    'SOS': 'Sh',  // Somali Shilling
    'SRD': r'SR$', // Surinam Dollar
    'SSP': '£',   // South Sudanese Pound
    'STN': 'Db',  // Dobra
    'SYP': '£',   // Syrian Pound
    'SZL': 'L',   // Lilangeni
    'THB': '฿',   // Baht
    'TJS': 'SM',  // Somoni
    'TMT': 'T',   // Turkmenistan New Manat
    'TND': 'د.ت', // Tunisian Dinar
    'TOP': 'T\$',  // Paʻanga
    'TRY': '₺',   // Turkish Lira
    'TTD': r'TT$', // Trinidad and Tobago Dollar
    'TVD': r'T$', // Tuvalu Dollar
    'TWD': r'NT$', // New Taiwan Dollar
    'TZS': 'TSh', // Tanzanian Shilling
    'UAH': '₴',   // Hryvnia
    'UGX': 'USh', // Uganda Shilling
    'USD': r'$',  // US Dollar
    'UYU': r'$U', // Peso Uruguayo
    'UZS': 'лв',  // Uzbekistan Sum
    'VES': 'Bs.S', // Bolívar Soberano
    'VND': '₫',   // Dong
    'VUV': 'VT',  // Vatu
    'WST': 'WS\$', // Tala
    'XAF': 'FCFA', // CFA Franc BEAC
    'XCD': r'EC$', // East Caribbean Dollar
    'XOF': 'CFA',  // CFA Franc BCEAO
    'XPF': '₣',   // CFP Franc
    'YER': '﷼',  // Yemeni Rial
    'ZAR': 'R',   // Rand
    'ZMW': 'ZK',  // Zambian Kwacha
    'ZWL': r'Z$', // Zimbabwe Dollar
  };

  static String symbol(String? code) {
    if (code == null) return '';
    return _currencySymbols[code] ?? code;
  }
}
