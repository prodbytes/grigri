import 'dart:js_interop';

extension type _Element(JSObject _) implements JSObject {
  external set lang(String value);
}

@JS('document.documentElement')
external _Element? get _root;

/// `<html lang="es">`.
void setDocumentLanguage(String languageCode) => _root?.lang = languageCode;
