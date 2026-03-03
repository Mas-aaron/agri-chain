import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agri_chain/services/recommendation_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Agrochemicals'),
              Tab(text: 'Approved Sellers'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ChemicalsTab(),
            _SellersTab(),
          ],
        ),
      ),
    );
  }
}

class _ChemicalsTab extends StatelessWidget {
  const _ChemicalsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('agro_chemicals').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;

        return Scaffold(
          body: ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final chem = CreditedAgrochemical.fromJson(data, docs[i].id);
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(chem.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Target: ${chem.target}\nActive: ${chem.activeIngredient}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showEditChemicalDialog(context, chem),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await FirebaseFirestore.instance.collection('agro_chemicals').doc(chem.id).delete();
                          await RecommendationService.reload();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            heroTag: 'add_chem',
            onPressed: () => _showAddChemicalDialog(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _showAddChemicalDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final activeCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final usageCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Agrochemical'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 8),
              TextField(controller: activeCtrl, decoration: const InputDecoration(labelText: 'Active Ingredient')),
              const SizedBox(height: 8),
              TextField(controller: targetCtrl, decoration: const InputDecoration(labelText: 'Targets (comma separated)')),
              const SizedBox(height: 8),
              TextField(controller: usageCtrl, decoration: const InputDecoration(labelText: 'Usage Notes')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final newChem = CreditedAgrochemical(
                id: '',
                name: nameCtrl.text,
                activeIngredient: activeCtrl.text,
                target: targetCtrl.text,
                usage: usageCtrl.text,
                isCredited: true,
                approvedSellerIds: [],
              );
              await FirebaseFirestore.instance.collection('agro_chemicals').add(newChem.toJson());
              await RecommendationService.reload();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditChemicalDialog(BuildContext context, CreditedAgrochemical chem) {
    final nameCtrl = TextEditingController(text: chem.name);
    final activeCtrl = TextEditingController(text: chem.activeIngredient);
    final targetCtrl = TextEditingController(text: chem.target);
    final usageCtrl = TextEditingController(text: chem.usage);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Agrochemical'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 8),
              TextField(controller: activeCtrl, decoration: const InputDecoration(labelText: 'Active Ingredient')),
              const SizedBox(height: 8),
              TextField(controller: targetCtrl, decoration: const InputDecoration(labelText: 'Targets (comma separated)')),
              const SizedBox(height: 8),
              TextField(controller: usageCtrl, decoration: const InputDecoration(labelText: 'Usage Notes')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('agro_chemicals').doc(chem.id).update({
                'name': nameCtrl.text,
                'activeIngredient': activeCtrl.text,
                'target': targetCtrl.text,
                'usage': usageCtrl.text,
              });
              await RecommendationService.reload();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _SellersTab extends StatelessWidget {
  const _SellersTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('agro_sellers').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;

        return Scaffold(
          body: ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final seller = ApprovedSeller.fromJson(data, docs[i].id);
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(seller.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${seller.location} • ${seller.phone}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showEditSellerDialog(context, seller),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await FirebaseFirestore.instance.collection('agro_sellers').doc(seller.id).delete();
                          await RecommendationService.reload();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            heroTag: 'add_seller',
            onPressed: () => _showAddSellerDialog(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _showAddSellerDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final licenseCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Seller'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 8),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 8),
              TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: 'Location')),
              const SizedBox(height: 8),
              TextField(controller: licenseCtrl, decoration: const InputDecoration(labelText: 'License ID')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final newSeller = ApprovedSeller(
                id: '',
                name: nameCtrl.text,
                phone: phoneCtrl.text,
                location: locationCtrl.text,
                isApproved: true,
                licenseId: licenseCtrl.text.isEmpty ? null : licenseCtrl.text,
              );
              await FirebaseFirestore.instance.collection('agro_sellers').add(newSeller.toJson());
              await RecommendationService.reload();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditSellerDialog(BuildContext context, ApprovedSeller seller) {
    final nameCtrl = TextEditingController(text: seller.name);
    final phoneCtrl = TextEditingController(text: seller.phone);
    final locationCtrl = TextEditingController(text: seller.location);
    final licenseCtrl = TextEditingController(text: seller.licenseId ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Seller'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 8),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 8),
              TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: 'Location')),
              const SizedBox(height: 8),
              TextField(controller: licenseCtrl, decoration: const InputDecoration(labelText: 'License ID')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('agro_sellers').doc(seller.id).update({
                'name': nameCtrl.text,
                'phone': phoneCtrl.text,
                'location': locationCtrl.text,
                'licenseId': licenseCtrl.text.isEmpty ? null : licenseCtrl.text,
              });
              await RecommendationService.reload();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
