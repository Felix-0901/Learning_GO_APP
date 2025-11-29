import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ⭐ 右側選單：縮小寬度 + 白色背景
      endDrawer: _buildRightMenu(context),
      appBar: AppBar(
        title: const Text('Charts'),
        actions: [
          Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  Scaffold.of(context).openEndDrawer();
                },
              );
            },
          ),
        ],
      ),
      body: const Center(child: Text('Under development…')),
    );
  }

  Widget _buildRightMenu(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Drawer(
      // 👉 讓右側選單只佔螢幕寬度的 60%（你可以改 0.5 / 0.4）
      width: width * 0.6,
      // 👉 明確指定白色背景
      backgroundColor: Colors.white,
      elevation: 16,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Menu',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            Divider(),
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Menu item 1'),
            ),
          ],
        ),
      ),
    );
  }
}
