<template>
  <div>
    Stack Trace:<br>
    <div class="backtrace">
      <div v-for="bt in backtrace" v-bind:key="bt" v-html="makeURL(bt, bt)"></div>
    </div>
  </div>
</template>

<script>
export default {
  name: 'Backtrace',
  props: ['url', 'backtrace'],
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
</style>

