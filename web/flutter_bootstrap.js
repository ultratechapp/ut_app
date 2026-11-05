{{flutter_js}}
{{flutter_build_config}}

// Bez usług Google: czcionki zapasowe (dla znaków spoza Manrope) nie są pobierane z fonts.gstatic.com.
_flutter.loader.load({
  config: {
    fontFallbackBaseUrl: 'fonts/',
  },
});
