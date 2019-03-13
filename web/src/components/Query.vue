<template>
  <div class="query">
    <div class="row">
      <div class="col-3">
        <a href="#" v-on:click="expandToggle">
          <span stlye="text-align: right">{{ expandText }}</span>
        </a>
        {{ query.table }}
      </div>
      <div class="col-5">{{ truncate(query.sql, 50) }}</div>
      <div class="col-3" v-html="makeURL(query.backtrace[0], shortLocation(query))"></div>
      <div class="col-1">{{ query.severity }}</div>
    </div>
    <div class="row" v-if="expanded">
      <div class="col-12">
        <div class="query-info-box">
          <sql v-bind:query="query"></Sql>
          <div v-if="query.backtrace && query.backtrace.length > 0">
            <backtrace v-bind:backtrace="query.backtrace" v-bind:url="url"></backtrace>
          </div>
          <table class="shiba-messages">
            <component v-for="message in query.messages" v-bind:is="'tag-' + message.tag" v-bind="message" v-bind:key="query.md5 + ':' + message.tag"></component>
          </table>
          <div v-if="debug" style="font-size: 10px">md5: {{ query.md5 }}</div>
          <div v-if="!rawExpanded">
            <a href="#" v-on:click.prevent="rawExpanded = !rawExpanded">See full EXPLAIN</a>
          </div>
          <div v-else>
            <a href="#" v-on:click.prevent="rawExpanded = !rawExpanded">hide EXPLAIN</a>
            <pre class="backtrace">{{  JSON.stringify(query.raw_explain, null, 2) }}</pre>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
  import Backtrace from './Backtrace.vue'
  import Sql from './Sql.vue'

  export default {
    name: 'Query',
    template: '#query-template',
    props: ['query', 'tags', 'url', 'debug'],
    data: function () {
      return {
        expanded: false,
        rawExpanded: false
      };
    },
    components: {
      backtrace: Backtrace,
      sql: Sql
    },
    methods: {
      makeURL: function(line, content) {
        if ( !this.url || !line )
          return content;

        var matches = line.match(/(.+):(\d+):/);
        var f = matches[1].replace(/^\/+/, '');
        var l = matches[2];

        return `<a href='${this.url}/${f}#L${l}' target='_new'>${content}</a>`;
      },
      truncate: function (string, len) {
        if ( string.length > len ) {
          return string.substring(0, len - 3) + "...";
        } else {
          return string;
        }
      },
      expandInfo: function(tag, event) {
        this.$modal.show('dialog', {
          title: this.tags[tag].title,
          text: this.tags[tag].description,
          buttons: [
            {
              title: 'Close'
            }
          ]
        })
        event.preventDefault();
      },
      expandToggle: function(event) {
        if (event) event.preventDefault()
        this.expanded = !this.expanded;
      },
      shortLocation: function(query) {
        if ( !query.backtrace || query.backtrace.length == 0 )
          return null;
        var location = query.backtrace[0];
        return location.match(/([^/]+:\d+):/)[1];
      },
    },
    computed: {
      expandText: function() {
        return this.expanded ? "-" : "+";
      }
    }
  };
</script>
<style>
  .query-info-box {
    border: 1px solid black;
    padding: 10px;
    margin: 5px;
  }
</style>


