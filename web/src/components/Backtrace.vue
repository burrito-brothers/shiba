<template>
  <div>
    Stack Trace:<br>
    <div class="backtrace">
      <div class="backtrace-toggle">
        <a href="#" v-on:click.prevent="filtered = !filtered">
          <span v-if="filtered">[show full backtrace]</span>
          <span v-else>[show filtered backtrace]</span>
        </a>
      </div>
      <div v-for="bt in filteredBacktrace" v-html="makeURL(bt, bt)" v-bind:key="bt.uniqId"></div>
    </div>
  </div>
</template>

<script>
import _ from 'lodash';

export default {
  name: 'Backtrace',
  data: () => ( { filtered: true } ),
  props: ['url', 'backtrace'],
  computed: {
    btWithIDs () {
      return this.bactrace.map((e) => { e.uniqId = _.uniqueId() ; e });
    },
    filteredBacktrace () {
      var bt = [];

      if ( !this.filtered )
        return this.backtrace;

      this.backtrace.forEach((b) => {
        if ( !b.match(/^gem/) )
          bt.push(b);
      });
      return bt;
    }
  },
  methods: {
    makeURL: function(line, content) {
      if ( !this.url || !line )
        return content;

      var matches = line.match(/(.+):(\d+):/);
      var f = matches[1].replace(/^\/+/, '');
      var l = matches[2];

      return `<a href='${this.url}/${f}#L${l}' target='_new'>${content}</a>`;
    }
  }
}
</script>
<style>
  .backtrace {
    font-family: monospace;
    background-color: #EEEEEE;
    padding: 5px;
    margin: 10px
  }
  .backtrace-toggle {
    float: right;
  }
</style>

