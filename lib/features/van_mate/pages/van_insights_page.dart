import 'package:flutter/material.dart';

class VanInsightsPage extends StatelessWidget {
  const VanInsightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF5F95FF).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF5F95FF).withValues(alpha: 0.30),
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.insights_outlined,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Business Insights',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Coming Soon',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF78D8C0).withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Business Insights will bring together business performance, revenue trends, booking trends, customer insights, smart recommendations and community insights.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.76),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
