import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../utils/app_theme.dart';
import '../widgets/widgets.dart';

final _sb = Supabase.instance.client;

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() { super.initState(); _tabCtrl = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [AppLogo(size: 28, showText: false), SizedBox(width: 10), Text('Admin Dashboard')]),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () async {
          await auth.signOut();
          if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
        })],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [Tab(text: 'Overview'), Tab(text: 'Users'), Tab(text: 'Listings')],
          labelColor: Colors.white, unselectedLabelColor: Colors.white60, indicatorColor: AppColors.accent,
        ),
      ),
      body: TabBarView(controller: _tabCtrl, children: const [_OverviewTab(), _UsersTab(), _ListingsTab()]),
    );
  }
}

class _OverviewTab extends StatefulWidget {
  const _OverviewTab();
  @override State<_OverviewTab> createState() => _OverviewTabState();
}
class _OverviewTabState extends State<_OverviewTab> {
  Map<String,int> _stats = {'users':0,'listings':0,'bookings':0,'pending':0};
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final u = await _sb.from('users').select('id');
    final l = await _sb.from('listings').select('id').eq('is_active', true);
    final b = await _sb.from('bookings').select('id');
    final p = await _sb.from('bookings').select('id').eq('status', 'Pending');
    setState(() {
      _stats = {'users':(u as List).length,'listings':(l as List).length,'bookings':(b as List).length,'pending':(p as List).length};
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
      _sc('Total Users', _stats['users']!, Icons.people_outline, AppColors.primary),
      const SizedBox(height:12),
      _sc('Active Listings', _stats['listings']!, Icons.agriculture, AppColors.success),
      const SizedBox(height:12),
      _sc('Total Bookings', _stats['bookings']!, Icons.book_online, AppColors.accent),
      const SizedBox(height:12),
      _sc('Pending Approvals', _stats['pending']!, Icons.pending_actions, AppColors.warning),
      const SizedBox(height:24),
      Text('System Status', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height:12),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        _sr('Supabase Auth','Operational',AppColors.success), const Divider(),
        _sr('PostgreSQL DB','Operational',AppColors.success), const Divider(),
        _sr('Supabase Storage','Operational',AppColors.success), const Divider(),
        _sr('Realtime Subscriptions','Operational',AppColors.success),
      ]))),
    ]));
  }

  Widget _sc(String l, int v, IconData i, Color c) => Card(child: ListTile(
    leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(i, color: c)),
    title: Text(l),
    trailing: Text('$v', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: c)),
  ));

  Widget _sr(String s, String st, Color c) => Padding(padding: const EdgeInsets.symmetric(vertical:8), child: Row(children: [
    Container(width:8,height:8,decoration: BoxDecoration(color:c,shape:BoxShape.circle)),
    const SizedBox(width:10), Expanded(child: Text(s)),
    Text(st, style: TextStyle(color:c, fontWeight: FontWeight.w700)),
  ]));
}

class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override State<_UsersTab> createState() => _UsersTabState();
}
class _UsersTabState extends State<_UsersTab> {
  List<UserModel> _users = []; bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final rows = await _sb.from('users').select().order('created_at', ascending: false);
    setState(() { _users = (rows as List).map((r) => UserModel.fromMap(r)).toList(); _loading = false; });
  }
  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(onRefresh: _load, child: ListView.separated(
      padding: const EdgeInsets.all(16), itemCount: _users.length,
      separatorBuilder: (_, __) => const Divider(height:1),
      itemBuilder: (_, i) {
        final u = _users[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: u.role == AppConstants.roleAdmin
                ? AppColors.accent.withOpacity(0.15)
                : AppColors.primary.withOpacity(0.12),
            child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : 'U',
              style: TextStyle(color: u.role == AppConstants.roleAdmin ? AppColors.accent : AppColors.primary, fontWeight: FontWeight.w700)),
          ),
          title: Text(u.name), subtitle: Text('${u.email} · ${u.role}'),
          trailing: u.isVerified
            ? const Icon(Icons.verified, color: AppColors.primary, size: 20)
            : TextButton(onPressed: () async {
                await _sb.from('users').update({'is_verified': true}).eq('id', u.id);
                _load();
              }, child: const Text('Verify', style: TextStyle(fontSize: 12))),
        );
      },
    ));
  }
}

class _ListingsTab extends StatefulWidget {
  const _ListingsTab();
  @override State<_ListingsTab> createState() => _ListingsTabState();
}
class _ListingsTabState extends State<_ListingsTab> {
  List<EquipmentListing> _listings = []; bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final rows = await _sb.from('listings').select().order('created_at', ascending: false);
    setState(() { _listings = (rows as List).map((r) => EquipmentListing.fromMap(r)).toList(); _loading = false; });
  }
  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(onRefresh: _load, child: ListView.separated(
      padding: const EdgeInsets.all(16), itemCount: _listings.length,
      separatorBuilder: (_, __) => const Divider(height:1),
      itemBuilder: (_, i) {
        final l = _listings[i];
        return ListTile(
          leading: Container(width:48,height:48,
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: l.imageUrls.isNotEmpty
              ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(l.imageUrls.first, fit: BoxFit.cover))
              : const Icon(Icons.agriculture, color: AppColors.primary)),
          title: Text(l.name),
          subtitle: Text('${l.type} · ₹${l.pricePerDay.toInt()}/day · ${l.ownerName}'),
          trailing: Switch(value: l.isActive, activeColor: AppColors.primary, onChanged: (v) async {
            await _sb.from('listings').update({'is_active': v}).eq('id', l.id);
            _load();
          }),
        );
      },
    ));
  }
}
