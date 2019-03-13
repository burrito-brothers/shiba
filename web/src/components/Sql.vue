<template>
  <div class="sql">
    <span>{{ query.select() }}</span>
    <span v-if="!expandFields && query.fields().length > 80">
      <a href="#" v-on:click.prevent="expandFields = !expandFields">...</a>
    </span>
    <span v-else>{{ query.fields() }}</span>
    <span>{{ query.rest(3) }}</span>
  </div>
</template>

<script>
export default {
  name: 'Sql',
  props: ['query'],
  data: () => (
    { expandFields: false }
  )
}
</script>


