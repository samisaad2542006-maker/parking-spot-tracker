import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../db/database_helper.dart';
import '../models/parking_location.dart';
import '../theme.dart';

String timeAgo(int ms) {
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
  if (d.inMinutes < 1) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseHelper.instance;
  List<ParkingLocation> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _db.getLocations();
    if (mounted) setState(() => _items = list);
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));

  Future<void> _navigate(ParkingLocation l) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${l.latitude},${l.longitude}&travelmode=walking');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _toast('Could not open Maps');
    } catch (_) {
      _toast('Could not open Maps');
    }
  }

  Future<void> _openForm([ParkingLocation? existing]) async {
    final result = await showModalBottomSheet<ParkingLocation>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SpotForm(existing: existing),
    );
    if (result == null) return;
    if (existing == null) {
      await _db.addLocation(result);
      _toast('Parking spot saved');
    } else {
      await _db.editLocation(result);
      _toast('Parking spot updated');
    }
    await _load();
  }

  Future<void> _confirmDelete(ParkingLocation l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this spot?'),
        content: Text('${l.areaName} · Floor ${l.floorNumber} · Spot ${l.spotNumber}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                minimumSize: const Size(90, 44),
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _db.removeLocation(l.id!);
    _toast('Parking spot deleted');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parking Tracker'),
        actions: [
          PopupMenuButton<ThemeMode>(
            tooltip: 'Theme',
            icon: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
            onSelected: ThemeController.set,
            itemBuilder: (_) => const [
              PopupMenuItem(value: ThemeMode.light, child: ListTile(leading: Icon(Icons.light_mode_rounded), title: Text('Light'))),
              PopupMenuItem(value: ThemeMode.dark, child: ListTile(leading: Icon(Icons.dark_mode_rounded), title: Text('Dark'))),
              PopupMenuItem(value: ThemeMode.system, child: ListTile(leading: Icon(Icons.settings_suggest_rounded), title: Text('System'))),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Save spot'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          _HeroCard(
            current: _items.isEmpty ? null : _items.first,
            isDark: isDark,
            onNavigate: _navigate,
          ),
          const SizedBox(height: 28),
          Text('Saved locations',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(children: [
                Icon(Icons.local_parking_rounded, size: 56, color: scheme.outline),
                const SizedBox(height: 12),
                Text('Nothing saved yet', style: TextStyle(color: scheme.onSurfaceVariant)),
              ]),
            ),
          for (var i = 0; i < _items.length; i++) ...[
            _SpotCard(
              item: _items[i],
              isCurrent: i == 0,
              onEdit: () => _openForm(_items[i]),
              onDelete: () => _confirmDelete(_items[i]),
              onNavigate: () => _navigate(_items[i]),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final ParkingLocation? current;
  final bool isDark;
  final void Function(ParkingLocation) onNavigate;
  const _HeroCard({required this.current, required this.isDark, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final c = current;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF2A4FB8), Color(0xFF16264F)]
              : const [Color(0xFF2F6BFF), Color(0xFF1B3FB8)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.directions_car_rounded, color: Colors.white70, size: 20),
            const SizedBox(width: 8),
            Text(c == null ? 'No car saved' : 'Your car is parked at',
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ]),
          const SizedBox(height: 10),
          Text(c?.areaName ?? 'Tap "Save spot" to start',
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
          if (c != null) ...[
            const SizedBox(height: 16),
            Row(children: [
              _pill(Icons.layers_rounded, 'Floor ${c.floorNumber}'),
              const SizedBox(width: 10),
              _pill(Icons.pin_drop_rounded, 'Spot ${c.spotNumber}'),
            ]),
            const SizedBox(height: 14),
            Text('Saved ${timeAgo(c.updatedAt)}',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            if (c.hasGps) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => onNavigate(c),
                icon: const Icon(Icons.directions_walk_rounded),
                label: const Text('Navigate to my car'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1B3FB8),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white, size: 16),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _SpotCard extends StatelessWidget {
  final ParkingLocation item;
  final bool isCurrent;
  final VoidCallback onEdit, onDelete, onNavigate;
  const _SpotCard({
    required this.item,
    required this.isCurrent,
    required this.onEdit,
    required this.onDelete,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        onTap: onEdit,
        contentPadding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(Icons.local_parking_rounded, color: scheme.onPrimaryContainer),
        ),
        title: Row(children: [
          Flexible(child: Text(item.areaName, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700))),
          if (isCurrent) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: scheme.primary, borderRadius: BorderRadius.circular(8)),
              child: Text('Current', style: TextStyle(color: scheme.onPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ],
        ]),
        subtitle: Text('Floor ${item.floorNumber} · Spot ${item.spotNumber} · ${timeAgo(item.updatedAt)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.hasGps)
              IconButton(
                tooltip: 'Navigate',
                icon: Icon(Icons.directions_walk_rounded, color: scheme.primary),
                onPressed: onNavigate,
              ),
            PopupMenuButton<String>(
              onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_rounded), title: Text('Edit'))),
                PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_rounded), title: Text('Delete'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotForm extends StatefulWidget {
  final ParkingLocation? existing;
  const _SpotForm({this.existing});

  @override
  State<_SpotForm> createState() => _SpotFormState();
}

class _SpotFormState extends State<_SpotForm> {
  final _key = GlobalKey<FormState>();
  late final _area = TextEditingController(text: widget.existing?.areaName);
  late final _floor = TextEditingController(text: widget.existing?.floorNumber);
  late final _spot = TextEditingController(text: widget.existing?.spotNumber);
  late double? _lat = widget.existing?.latitude;
  late double? _lng = widget.existing?.longitude;
  bool _locating = false;
  String? _locError;

  @override
  void dispose() {
    _area.dispose();
    _floor.dispose();
    _spot.dispose();
    super.dispose();
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  Future<void> _captureLocation() async {
    setState(() {
      _locating = true;
      _locError = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'Please turn on Location (GPS) on your phone';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw 'Location permission denied. Allow it in phone settings.';
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (e) {
      if (mounted) setState(() => _locError = e.toString());
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _submit() {
    if (!_key.currentState!.validate()) return;
    Navigator.pop(
      context,
      ParkingLocation(
        id: widget.existing?.id,
        areaName: _area.text.trim(),
        floorNumber: _floor.text.trim(),
        spotNumber: _spot.text.trim(),
        latitude: _lat,
        longitude: _lng,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(editing ? 'Edit parking spot' : 'Save parking spot',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            TextFormField(
              controller: _area,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Parking area', hintText: 'e.g. Gate 3, Lot B',
                  prefixIcon: Icon(Icons.place_rounded)),
              validator: _req,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _floor,
                  decoration: const InputDecoration(labelText: 'Floor', prefixIcon: Icon(Icons.layers_rounded)),
                  validator: _req,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _spot,
                  decoration: const InputDecoration(labelText: 'Spot number', prefixIcon: Icon(Icons.pin_drop_rounded)),
                  validator: _req,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _locating ? null : _captureLocation,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _locating
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_lat == null ? Icons.my_location_rounded : Icons.check_circle_rounded),
              label: Text(_lat == null ? 'Use my current location' : 'Location captured · tap to refresh'),
            ),
            if (_lat != null && _lng != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text('${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
              ),
            if (_locError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(_locError!, style: TextStyle(color: scheme.error, fontSize: 13)),
              ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _submit, child: Text(editing ? 'Update' : 'Save')),
          ],
        ),
      ),
    );
  }
}