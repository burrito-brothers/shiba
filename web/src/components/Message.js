var template = `
<tr>
  <td class="shiba-badge-td">
  <a class="badge" v-bind:style="costToColor">::TITLE::</a>
  </td>
  <td class="shiba-message">
    ::SUMMARY::
  </td>
  <td class="running-totals">
    {{ formattedRunningCost }}
  </td>
</tr>
`

var greenToRedGradient = [
  '#57bb8a','#63b682', '#73b87e', '#84bb7b', '#94bd77', '#a4c073', '#b0be6e',
  '#c4c56d', '#d4c86a', '#e2c965', '#f5ce62', '#f3c563', '#e9b861', '#e6ad61',
  '#ecac67', '#e9a268', '#e79a69', '#e5926b', '#e2886c', '#e0816d', '#dd776e'
];

var templateComputedFunctions = {
  key_parts: function() {
    if ( this.index_used && this.index_used.length > 0 )
      return this.index_used.join(',');
    else
      return "";
  },
  fuzz_table_sizes: function() {
    var h = {};
    var tables = this.tables;

    Object.keys(tables).forEach(function(k) {
      var size = tables[k];
      if ( !h[size] )
        h[size] = [];

      h[size].push(k);
    });

    var sizesDesc = Object.keys(h).sort(function(a, b) { return b - a });
    var str = "";

    sizesDesc.forEach(function(size) {
      str = str + h[size].join(", ") + ": " + size.toLocaleString() + " rows.  ";
    });

    return str;
  },
  formatted_cost: function() {
    var readPercentage = (this.rows_read / this.table_size) * 100.0;
    if ( this.rows_read > 100 && readPercentage > 1 ) // todo: make better
      return `${readPercentage.toFixed()}% (${this.rows_read.toLocaleString()}) of the`;
    else
      return this.rows_read.toLocaleString();
  },
  costToColor: function() {
    var costScale = this.cost ? this.cost / 0.5 : 0;

    if ( costScale > 1 )
      costScale = 1;

    var pos =  (costScale * (greenToRedGradient.length - 1)).toFixed();

    return "border-color: " + greenToRedGradient[pos];
  },
  formattedRunningCost: function() {
    if ( this.running_cost === undefined )
      return "-";
    else if ( this.running_cost < 1.0 )
      return (this.running_cost * 100).toFixed() + "ms";
    else
      return this.running_cost.toFixed(1) + "s";
  },
  formatted_result: function() {
    var rb = this.result_bytes;
    var result;
    if ( rb == 0 )
      return "" + this.result_size + " rows";
    else if ( rb < 1000 )
      result = rb + " bytes ";
    else if ( rb < 1000000 )
      result = (rb / 1000).toFixed() + "kb ";
    else
      result = (rb / 1000000 ).toFixed(1) + "mb ";

    return result + " (" + this.result_size.toLocaleString() + " rows)";
  }
}

import Vue from 'vue'

export default function (tag, title, summary) {
  var tmpl = template.replace("::TITLE::", title).replace("::SUMMARY::", summary);

  Vue.component(`tag-${tag}`, {
    template: tmpl,
    props: [ 'table_size', 'result_size', 'table', 'cost', 'index', 'join_to', 'index_used', 'running_cost', 'tables', 'rows_read', 'result_bytes', 'server' ],
    computed: templateComputedFunctions,
    data: function () {
      return { lastRunnningCost: undefined };
    }
  });
}

