{{flutter_js}}
{{flutter_build_config}}

// Same as Flutter's default start-up, plus: report each step on the loading screen
// in index.html, and offer "Try again" if start-up fails.
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    var status = document.getElementById('loading-status');
    try {
      if (status) status.textContent = 'Starting up…';
      var appRunner = await engineInitializer.initializeEngine();
      if (status) status.textContent = 'Almost there…';
      await appRunner.runApp();
    } catch (error) {
      console.error('Lumina failed to start', error);
      if (window.luminaLoadFailed) window.luminaLoadFailed();
    }
  }
}).catch(function (error) {
  console.error('Lumina failed to load', error);
  if (window.luminaLoadFailed) window.luminaLoadFailed();
});
