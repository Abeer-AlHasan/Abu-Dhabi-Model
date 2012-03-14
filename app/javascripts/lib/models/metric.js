/* DO NOT MODIFY. This file was compiled Wed, 14 Mar 2012 10:10:21 GMT from
 * /Users/paozac/Sites/etmodel/app/coffeescripts/lib/models/metric.coffee
 */

(function() {

  this.Metric = {
    scale_unit: function(value, unit) {
      var power, u, unit_label;
      power = this.power_of_thousand(value);
      switch (unit) {
        case "PJ":
          u = "joules";
          power += 3;
          break;
        case "EUR":
          u = "euro";
          break;
        case "%":
          return "%";
        case "MW":
          u = "watt";
          power += 2;
          break;
        case "MT":
          u = "ton";
          break;
        default:
          u = unit;
      }
      unit_label = this.scaling_in_words(power, u);
      return unit_label;
    },
    scale_value: function(value, scale) {
      return value / Math.pow(1000, scale);
    },
    scaling_in_words: function(scale, unit) {
      var scale_symbols, symbol;
      scale_symbols = {
        "0": 'unit',
        "1": 'thousands',
        "2": 'millions',
        "3": 'billions',
        "4": 'trillions',
        "5": 'quadrillions',
        "6": 'quintillions'
      };
      if (_.isNaN(scale)) scale = 0;
      symbol = scale_symbols["" + scale];
      return I18n.t("units." + unit + "." + symbol);
    },
    round_number: function(value, precision) {
      var rounded;
      rounded = Math.pow(10, precision);
      return Math.round(value * rounded) / rounded;
    },
    calculate_performance: function(now, fut) {
      if (now === null || fut === null || fut === 0) return null;
      return fut / now - 1;
    },
    autoscale_value: function(x, unit, precision) {
      var pow, value;
      if (precision == null) precision = 0;
      if (x === 0) {
        pow = 0;
        value = 0;
      } else {
        pow = this.power_of_thousand(x);
        value = x / Math.pow(1000, pow);
        value = this.round_number(value, precision);
      }
      switch (unit) {
        case '%':
          return this.percentage_to_string(x);
        case 'MJ':
          return "" + value + (this.scaling_in_words(pow, 'joules'));
        case 'PJ':
          return "" + value + (this.scaling_in_words(pow + 3, 'joules'));
        case 'MW':
          return "" + value + (this.scaling_in_words(pow, 'watt'));
        case 'euro':
          return "&euro;" + value;
        case 'man_years':
          return x;
        default:
          return x;
      }
    },
    percentage_to_string: function(x, prefix, precision) {
      var value;
      precision = precision || 1;
      prefix = prefix || false;
      value = this.round_number(x, precision);
      if (prefix && value > 0.0) value = "+" + value;
      return "" + value + "%";
    },
    ratio_as_percentage: function(x, prefix, precision) {
      return this.percentage_to_string(x * 100, prefix, precision);
    },
    euros_to_string: function(x, unit_suffix) {
      var abs_value, prefix, rounded, scale, suffix, value;
      prefix = x < 0 ? "-" : "";
      abs_value = Math.abs(x);
      scale = this.power_of_thousand(x);
      value = abs_value / Math.pow(1000, scale);
      suffix = '';
      if (unit_suffix) {
        suffix = I18n.t('units.currency.' + this.power_of_thousand_to_string(scale));
      }
      rounded = this.round_number(value, 1).toString();
      if (abs_value < 1000 && _.indexOf(rounded, '.') !== -1) {
        rounded = rounded.split('.');
        if (rounded[1] && rounded[1].length === 1) rounded[1] += '0';
        rounded = rounded.join('.');
      }
      return "" + prefix + "&euro;" + rounded + suffix;
    },
    power_of_thousand: function(x) {
      return parseInt(Math.log(Math.abs(x)) / Math.log(1000));
    },
    power_of_thousand_to_string: function(x) {
      switch (x) {
        case 0:
          return 'unit';
        case 1:
          return 'thousands';
        case 2:
          return 'millions';
        case 3:
          return 'billions';
        case 4:
          return 'trillions';
        case 5:
          return 'quadrillions';
        case 6:
          return 'quintillions';
        default:
          return null;
      }
    }
  };

}).call(this);
