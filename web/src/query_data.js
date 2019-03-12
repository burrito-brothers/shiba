var severityIndexes = { high: 1, medium: 2, low: 3, none: 4 };

export default function QueryData(obj) {
  Object.assign(this, obj);
  this.severityIndex = severityIndexes[this.severity];
  this.splitSQL();
  this.makeSearchString();
}

QueryData.prototype = {
  makeSearchString: function() {
    var arr = [this.sql];
    arr = arr.concat(this.messages.map(function(m) { return m.tag }).join(':'));
    arr = arr.concat(this.backtrace.join(':'));

    this.searchString = arr.join(':').toLowerCase();
  },
  hasTag: function(tag) {
    return this.messages.find(function(m) {
      return m.tag == tag;
    });
  },
  splitSQL: function() {
    this.sqlFragments = this.sql.match(/(SELECT\s)(.*?)(\s+FROM .*)/i);
  },
  select: function () {
    return this.sqlFragments[1];
  },
  fields: function () {
    return this.sqlFragments[2];
  },
  rest: function(index) {
    return this.sqlFragments.slice(index).join('');
  }
};

QueryData.sortByFunc = function(fields) {
  return function(a, b) {
    for ( var i = 0 ; i < fields.length; i++ ) {
      if ( a[fields[i]] < b[fields[i]] )
        return -1;
      else if ( a[fields[i]] > b[fields[i]] )
        return 1;
    }
    return 0;
  }
}
