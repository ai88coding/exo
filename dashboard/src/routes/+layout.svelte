<script lang="ts">
  import "../app.css";
  import ToastContainer from "$lib/components/ToastContainer.svelte";
  import ConnectionBanner from "$lib/components/ConnectionBanner.svelte";

  let { children } = $props();
</script>

<svelte:head>
  <title>DGX Spark (數字馬研究室)</title>
  <meta name="description" content="Mac Spark - 數字馬研究室 AI Cluster Dashboard" />
</svelte:head>

<div class="min-h-screen bg-background text-foreground">
  <ConnectionBanner />
  {@render children?.()}
  <ToastContainer />
</div>
