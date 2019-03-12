<template>
  <div id="app" v-cloak>
    <v-dialog :width="600"></v-dialog>
    <div class="container" style="">
      <div class="row" v-if="hasFuzzed">
        <div class="alert alert-warning" role="alert">
          This query analysis was generated using estimated table sizes.
          To improve these results and find other problem queries beyond missing indexes, we'll need more stats.<br/>
          <a target="_blank" href="https://github.com/burrito-brothers/shiba/blob/master/README.md#going-beyond-table-scans">Find out how to get a more accurate analysis by feeding Shiba index stats</a>
        </div>
      </div>
      <div class="row">
        <div class="col-10"></div>
        <div class="col-2"><input :value="search" @input="updateSearch" placeholder="search..."></div>
      </div>
      <div class="row">
        <div class="col-12">We found {{ queries.length }} queries that
          <span v-if="search == ''">deserve your attention:</span>
          <span v-else>match your search term</span>
        </div>
      </div>
      <div class="row">
        <div class="col-3">Table</div>
        <div class="col-5">Query</div>
        <div class="col-3">Source</div>
        <div class="col-1">Severity</div>
      </div>
      <div class="queries">
        <Query v-for="query in queries" v-bind:query="query" v-bind:key="query.sql" v-bind:tags="tags" v-bind:url="url"></query>
      </div>
      <div v-if="search == ''">
        <div class="row">
          <div class="col-12">We also found <a href="#" v-on:click.prevent="lowExpanded = !lowExpanded">{{ queriesLow.length }} queries</a> that look fine.</div>
        </div>
        <a name="lowExapnded"></a>
        <div class="queries" v-if="lowExpanded">
          <query v-for="query in queriesLow" v-bind:query="query" v-bind:key="query.sql" v-bind:tags="tags" v-bind:url="url"></query>
        </div>
      </div>
      <div style="height:50px"></div>
    </div>
  </div>
</template>

<script>
import Query from './components/Query.vue'
import registerMessage from './components/Message.js'
import QueryData from './query_data.js'
import VModal from 'vue-js-modal';
import _ from 'lodash'
import Vue from 'vue';
import nanoajax from 'nanoajax';
import 'bootstrap/dist/css/bootstrap.min.css'

Vue.use(VModal, { dialog: true });

function categorizeQueries(v, queries) {
  queries.forEach(function(query) {
    var q = new QueryData(query);

    if ( q.severity == "none" ) {
      v.lowQ.push(q);
    } else {
      v.highQ.push(q);
    }

    if ( q.hasTag("fuzzed_data") )
      this.hasFuzzed = true;

    var rCost = 0;
    q.messages.forEach(function(m) {
      if ( m.cost && m.cost != 0) {
        rCost += m.cost;
        m.running_cost = rCost;
      } else {
        m.running_cost = undefined;
      }
    });
  });

  var f = QueryData.sortByFunc(['severityIndex', 'table']);
  v.highQ = v.highQ.sort(f);
  v.lowQ = v.lowQ.sort(f);
}


export default {
  name: 'app',
  data: () => ({
    highQ: [],
    lowQ: [],
    tags: {},
    lowExpanded: false,
    hasFuzzed: false,
    search: '',
    url: null
  }),
  mounted () {
    if  ( typeof(shibaData) === "undefined" ) {
      nanoajax.ajax({url:'/example_data.json'}, function (code, responseText) {
        if ( code == 200 ) {
          var data = JSON.parse(responseText);
          this.setupData(data);
        }
      }.bind(this));
    } else {
      // eslint-disable-next-line
      this.setupData(shibaData);
    }
  },
  methods: {
    setupData: function(data) {
      this.url = data.url;
      this.tags = data.tags;

      Object.keys(this.tags).forEach((k) => {
        registerMessage(k, this.tags[k].title, this.tags[k].summary);
      })
      categorizeQueries(this, data.queries);
    },
    updateSearch: _.debounce(function (e) {
      this.search = e.target.value;
    }, 500)
  },
  computed: {
    queries: function() {
      if ( this.search != '' ) {
        var filtered = [];
        var lcSearch = this.search.toLowerCase();
        this.highQ.concat(this.lowQ).forEach(function(q) {
          if ( q.searchString.includes(lcSearch) )
            filtered.push(q);
        });
        return filtered;
      } else
        return this.highQ;
    },
    queriesLow: function() {
      return this.lowQ;
    }
  },
  components: {
    Query
  }
}
</script>

<style>
  .sql {
    font-family: monospace;
  }

  .badge  {
    color: black;
    background-color: white;
    border-style: solid;
    border-width: 1.5px;
    margin-right: 5px;
    width: 100px;
  }

  .shiba-badge-td {
    width: 100px;
  }

  .shiba-messages {
    margin: 0px;
    margin-top: 10px;
    width: 100%;
  }

  .shiba-messages td {
  }

  .shiba-message {
    padding-right: 10px;
    width: 90%;
  }

  .running-totals {
    align: right;
    font-family: monospace;
  }
[v-cloak] { display: none }
</style>
