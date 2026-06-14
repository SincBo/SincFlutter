import 'dart:async';

import 'package:flutter/material.dart';

/// A reusable search bar widget that debounces user input and exposes
/// the debounced value through [onChanged]. It also shows a clear button
/// when text is not empty and calls [onChanged] with an empty string when cleared.
class DebouncedSearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final String? initialText;
  final Duration debounceDuration;
  final String hintText;

  const DebouncedSearchBar({
    Key? key,
    required this.onChanged,
    this.initialText,
    this.debounceDuration = const Duration(milliseconds: 300),
    this.hintText = 'Buscar',
  }) : super(key: key);

  @override
  State<DebouncedSearchBar> createState() => _DebouncedSearchBarState();
}

class _DebouncedSearchBarState extends State<DebouncedSearchBar> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText ?? '');
    _controller.addListener(() {
      setState(() {}); // update suffix icon visibility
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(widget.debounceDuration, () {
      widget.onChanged(value.trim());
    });
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _onTextChanged,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: _clear,
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
        contentPadding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 12.0),
      ),
    );
  }
}
