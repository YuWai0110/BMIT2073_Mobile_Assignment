import 'package:flutter/material.dart';

import 'skeleton_box.dart';

class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    const header = Column(
      children: [
        SkeletonBox(width: 88, height: 88, radius: 44),
        SizedBox(height: 12),
        SkeletonBox(width: 160, height: 22),
        SizedBox(height: 8),
        SkeletonBox(width: 200, height: 14),
      ],
    );
    final information = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: 160, height: 22),
            const SizedBox(height: 24),
            for (var i = 0; i < 4; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    SkeletonBox(width: 24, height: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 80, height: 12),
                          SizedBox(height: 8),
                          SkeletonBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    const logout = SkeletonBox(height: 88, radius: 12);
    return Semantics(
      label: 'Loading profile',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final landscape =
              MediaQuery.orientationOf(context) == Orientation.landscape &&
              constraints.maxWidth >= 700;
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: landscape
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        flex: 2,
                        child: Column(
                          children: [header, SizedBox(height: 24), logout],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(flex: 3, child: information),
                    ],
                  )
                : Column(
                    children: [
                      header,
                      const SizedBox(height: 28),
                      information,
                      const SizedBox(height: 16),
                      logout,
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class LoanApplicationsSkeleton extends StatelessWidget {
  const LoanApplicationsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading loan applications',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 160, height: 20),
          const SizedBox(height: 12),
          for (var i = 0; i < 3; i++)
            const Card(
              margin: EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    SkeletonBox(width: 36, height: 36, radius: 18),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          SkeletonBox(height: 16),
                          SizedBox(height: 10),
                          SkeletonBox(height: 12),
                        ],
                      ),
                    ),
                    SizedBox(width: 12),
                    SkeletonBox(width: 64, height: 24, radius: 12),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AiAdvisorSkeleton extends StatelessWidget {
  const AiAdvisorSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Generating AI advice',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < 4; i++)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SkeletonBox(height: 24),
            ),
        ],
      ),
    );
  }
}
