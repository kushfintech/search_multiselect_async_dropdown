part of '../multi_dropdown.dart';

/// Controller for the multiselect dropdown.
class MultiSelectController<T> extends ChangeNotifier {
  bool _initialized = false;
  bool _open = false;
  bool _isDisposed = false;
  String _searchQuery = '';

  List<DropdownItem<T>> _allList = [];
  List<DropdownItem<T>> _items = [];
  List<DropdownItem<T>> _filteredItems = [];

  OnSelectionChanged<T>? _onSelectionChanged;
  OnSearchChanged? _onSearchChanged;

  List<DropdownItem<T>> get items =>
      _searchQuery.isEmpty ? _items : _filteredItems;

  List<DropdownItem<T>> get selectedItems =>
      _allList.where((item) => item.selected).toList();

  List<T> get _selectedValues => selectedItems.map((e) => e.value).toList();

  List<DropdownItem<T>> get disabledItems =>
      _allList.where((item) => item.disabled).toList();

  bool get isOpen => _open;
  bool get isDisposed => _isDisposed;

  void _initialize() {
    _initialized = true;
  }

  void setItems(List<DropdownItem<T>> newItems) {
    // Preserve selection and disabled state from old list
    // Collect the values of previously selected and disabled items from _allList.
    final selectedValues =
        _allList.where((e) => e.selected).map((e) => e.value).toSet();
    final disabledValues =
        _allList.where((e) => e.disabled).map((e) => e.value).toSet();

    //  Map old items by value for lookup
    //Create a map from value to item for fast access later (helps find missing selected items).
    // This is useful for ensuring that selected items that are not in the new list
    final Map<T, DropdownItem<T>> existingMap = {
      for (var item in _allList) item.value: item,
    };

    // Update _allList using new items
    //Replace _allList with a new list based on newItems.
    //Keep selected and disabled flags if the item's value is in selectedValues or disabledValues.

    _allList =
        newItems.map((newItem) {
          return newItem.copyWith(
            selected: selectedValues.contains(newItem.value),
            disabled: disabledValues.contains(newItem.value),
          );
        }).toList();

    //Sort list with selected items first
    //Update _items to a version of _allList with selected items sorted first.
    _items = _sortSelectedFirst(_allList);

    // Filter list based on search query
    //If there's no search query, _filteredItems is the same as _items.
    //If there is a query, it filters and sorts _allList based on the query.
    _filteredItems =
        _searchQuery.isEmpty
            ? _sortSelectedFirst(_items)
            : _sortSelectedFirst(
              _allList
                  .where(
                    (item) => item.label.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ),
                  )
                  .toList(),
            );

    // Ensure selected items not in newItems stay in the list
    //Add back any selected items that were not in newItems
    //If a previously selected item was not included in newItems, add it back to _allList to preserve its selection.
    final selectedMissingItems =
        existingMap.entries
            .where(
              (entry) =>
                  selectedValues.contains(entry.key) &&
                  !_allList.any((i) => i.value == entry.key),
            )
            .map((entry) => entry.value.copyWith(selected: true))
            .toList();

    _allList.addAll(selectedMissingItems);
    _items = _sortSelectedFirst(_allList);

    //Update filtered items with missing selected items if search is active
    //If search is active, ensure those "missing but selected" items also appear in the filtered list.
    if (_searchQuery.isNotEmpty) {
      _filteredItems.addAll(
        selectedMissingItems.where((item) => !_filteredItems.contains(item)),
      );
    }

    notifyListeners();
    _onSelectionChanged?.call(_selectedValues);
  }

  void clearAll() {
    // Reset selections in _allList
    _allList =
        _allList
            .map(
              (item) => item.selected ? item.copyWith(selected: false) : item,
            )
            .toList();

    // Ensure that _items and _filteredItems are updated accordingly
    _items = _sortSelectedFirst(_allList);
    _filteredItems =
        _searchQuery.isEmpty
            ? List.from(_items)
            : _allList
                .where(
                  (item) => item.label.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ),
                )
                .toList();

    notifyListeners();
    _onSelectionChanged?.call(_selectedValues);
  }

  void selectAll() {
    _allList =
        _allList
            .map(
              (item) =>
                  item.disabled || item.selected
                      ? item
                      : item.copyWith(selected: true),
            )
            .toList();
    _items = _sortSelectedFirst(_allList);
    _filteredItems = List.from(_items);
    notifyListeners();
    _onSelectionChanged?.call(_selectedValues);
  }

  void selectAtIndex(int index) {
    if (index < 0 || index >= items.length) return;
    final item = items[index];
    if (item.disabled || item.selected) return;
    toggleWhere((element) => element.value == item.value);
  }

  void toggleWhere(bool Function(DropdownItem<T>) predicate) {
    _allList =
        _allList.map((item) {
          if (predicate(item)) {
            return item.copyWith(selected: !item.selected);
          }
          return item;
        }).toList();
    _items = _sortSelectedFirst(_allList);
    _updateFilteredItems();
    notifyListeners();
    _onSelectionChanged?.call(_selectedValues);
  }

  void selectWhere(bool Function(DropdownItem<T> item) predicate) {
    _allList =
        _allList
            .map(
              (element) =>
                  predicate(element) && !element.selected
                      ? element.copyWith(selected: true)
                      : element,
            )
            .toList();
    _items = _sortSelectedFirst(_allList);
    _updateFilteredItems();
    notifyListeners();
    _onSelectionChanged?.call(_selectedValues);
  }

  void _toggleOnly(DropdownItem<T> item) {
    _allList =
        _allList
            .map(
              (element) =>
                  element == item
                      ? element.copyWith(selected: !element.selected)
                      : element.copyWith(selected: false),
            )
            .toList();
    _items = _sortSelectedFirst(_allList);
    _updateFilteredItems();
    notifyListeners();
    _onSelectionChanged?.call(_selectedValues);
  }

  void unselectWhere(bool Function(DropdownItem<T>) predicate) {
    _allList =
        _allList.map((item) {
          if (predicate(item) && item.selected) {
            return item.copyWith(selected: false);
          }
          return item;
        }).toList();
    _items = _sortSelectedFirst(_allList);
    _updateFilteredItems();
    notifyListeners();
    _onSelectionChanged?.call(_selectedValues);
  }

  void disableWhere(bool Function(DropdownItem<T>) predicate) {
    _allList =
        _allList.map((item) {
          if (predicate(item) && !item.disabled) {
            return item.copyWith(disabled: true);
          }
          return item;
        }).toList();
    _items = _sortSelectedFirst(_allList);
    _updateFilteredItems();
    notifyListeners();
    _onSelectionChanged?.call(_selectedValues);
  }

  void openDropdown() {
    if (_open) return;
    _open = true;
    notifyListeners();
  }

  void closeDropdown() {
    if (!_open) return;
    _open = false;
    notifyListeners();
  }

  void _setOnSelectionChange(OnSelectionChanged<T>? onSelectionChanged) {
    _onSelectionChanged = onSelectionChanged;
  }

  void _setOnSearchChange(OnSearchChanged? onSearchChanged) {
    _onSearchChanged = onSearchChanged;
  }

  void _setSearchQuery(String query) {
    _searchQuery = query;
    _updateFilteredItems();
    _onSearchChanged?.call(query);
    notifyListeners();
  }

  void _updateFilteredItems() {
    if (_searchQuery.isEmpty) {
      _filteredItems = _sortSelectedFirst(_items);
    } else {
      final matchingItems =
          _allList.where((item) {
            final matchesQuery = item.label.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );

            return matchesQuery || item.selected; // Always include selected
          }).toList();

      _filteredItems = matchingItems;

      // _filteredItems = _sortSelectedFirst(matchingItems);
    }
  }

  List<DropdownItem<T>> _sortSelectedFirst(List<DropdownItem<T>> items) {
    final selected = items.where((item) => item.selected).toList();
    final unselected = items.where((item) => !item.selected).toList();
    return [...selected, ...unselected];
  }

  void _clearSearchQuery({bool notify = false}) {
    _searchQuery = '';
    _updateFilteredItems();
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    super.dispose();
    _isDisposed = true;
  }

  @override
  String toString() {
    return 'MultiSelectController(items: $_items, open: $_open)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MultiSelectController<T> &&
        listEquals(other._items, _items) &&
        other._open == _open;
  }

  @override
  int get hashCode => _items.hashCode ^ _open.hashCode;
}
