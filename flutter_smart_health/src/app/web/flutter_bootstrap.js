{{flutter_js}}
{{flutter_build_config}}

(function () {
  var buildTag = window.__ehospitalBuildTag || String(Date.now());
  if (_flutter && _flutter.buildConfig && Array.isArray(_flutter.buildConfig.builds)) {
    _flutter.buildConfig.builds.forEach(function (build) {
      if (build && build.mainJsPath && build.mainJsPath.indexOf('?') === -1) {
        build.mainJsPath = build.mainJsPath + '?v=' + encodeURIComponent(buildTag);
      }
    });
  }
  _flutter.loader.load();
})();
