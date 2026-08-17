import 'package:alphax/alphax.dart';
import 'package:flutter/material.dart';

import '../../app/waypoint_controller.dart';
import '../../data/waypoint_json.dart';
import '../waypoint_theme.dart';
import '../waypoint_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final WaypointController controller;

  @override
  Widget build(BuildContext context) {
    final capabilities = controller.capabilities;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 52),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              WaypointSectionHeader(
                eyebrow: 'Under the hood',
                title: 'Transport lab.',
                action: WaypointStatusPill(
                  label: controller.repository.name,
                  color: WaypointColors.mint,
                ),
              ),
              const SizedBox(height: 11),
              Text(
                'See what the configured client can do, what it actually negotiated, and where it will fail closed.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 26),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 760;
                  final left = _ProtocolCard(controller: controller);
                  final right = _SecurityCard(controller: controller);
                  return wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(child: left),
                            const SizedBox(width: 16),
                            Expanded(child: right),
                          ],
                        )
                      : Column(
                          children: <Widget>[
                            left,
                            const SizedBox(height: 16),
                            right,
                          ],
                        );
                },
              ),
              const SizedBox(height: 16),
              _CapabilityCard(capabilities: capabilities),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProtocolCard extends StatelessWidget {
  const _ProtocolCard({required this.controller});

  final WaypointController controller;

  @override
  Widget build(BuildContext context) {
    final probe = controller.lastProbe;
    return WaypointSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const WaypointEyebrow('Protocol truth'),
              const Spacer(),
              const Icon(
                Icons.compare_arrows_rounded,
                color: WaypointColors.mintDeep,
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            'Preference is not a promise.',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Ask for H3, then inspect the protocol that completed the request.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 21),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: WaypointColors.canvas,
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.network_check_rounded,
                  color: WaypointColors.mintDeep,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    probe == null
                        ? 'No probe run yet'
                        : 'Actual: ${WaypointJson.protocolLabel(probe.protocol)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (probe?.fallback != null)
                  const WaypointStatusPill(
                    label: 'fallback',
                    color: WaypointColors.peach,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: () => controller.probe(),
                  child: const Text('Prefer H3'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => controller.probe(requireHttp3: true),
                  child: const Text('Require H3'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Required H3 is fail-closed. Unknown metadata never counts as success.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _SecurityCard extends StatelessWidget {
  const _SecurityCard({required this.controller});

  final WaypointController controller;

  @override
  Widget build(BuildContext context) {
    final isDemo = controller.repository.isDemo;
    return WaypointSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const WaypointEyebrow('Security defaults'),
              const Spacer(),
              const Icon(Icons.shield_outlined, color: WaypointColors.mintDeep),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            isDemo ? 'A local fixture.' : 'Verified by default.',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Waypoint keeps the transport policy visible without exposing secrets in logs or UI.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          _SecurityRow(
            icon: Icons.lock_outline_rounded,
            label: 'TLS',
            value: isDemo
                ? 'Not applicable in demo'
                : controller.repository.tlsPolicy.isPlatformDefault
                ? 'Platform trust'
                : 'Custom policy',
          ),
          _SecurityRow(
            icon: Icons.alt_route_rounded,
            label: 'Proxy',
            value: isDemo
                ? 'Not applicable in demo'
                : controller.repository.proxyPolicy.mode.name,
          ),
          _SecurityRow(
            icon: Icons.block_rounded,
            label: 'Trust-all',
            value: isDemo ? 'Not exercised' : 'Never enabled',
            good: !isDemo,
          ),
          const SizedBox(height: 10),
          Text(
            isDemo
                ? 'Demo mode is local fixture data; it does not exercise TLS or proxy behavior.'
                : 'Pins and proxy credentials belong in secure application configuration, never in this demo.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _SecurityRow extends StatelessWidget {
  const _SecurityRow({
    required this.icon,
    required this.label,
    required this.value,
    this.good = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool good;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Row(
      children: <Widget>[
        Icon(icon, size: 18, color: WaypointColors.muted),
        const SizedBox(width: 10),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: good ? WaypointColors.mintDeep : WaypointColors.ink,
          ),
        ),
      ],
    ),
  );
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({required this.capabilities});

  final AlphaXCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    const items = <(String, AlphaXCapability)>[
      ('HTTP/1.1', AlphaXCapability.http11),
      ('HTTP/2', AlphaXCapability.http2),
      ('HTTP/3', AlphaXCapability.http3),
      ('Streaming', AlphaXCapability.streamingDownload),
      ('File transfer', AlphaXCapability.nativeFileDownload),
      ('Actual protocol', AlphaXCapability.negotiatedProtocolReporting),
    ];
    return WaypointSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(child: WaypointEyebrow('Capability snapshot')),
              Text(
                capabilities.transportName ?? 'Unknown transport',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (final item in items)
                _CapabilityChip(
                  label: item.$1,
                  support: capabilities.supportFor(item.$2),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({required this.label, required this.support});

  final String label;
  final AlphaXSupport support;

  @override
  Widget build(BuildContext context) {
    final supported = support == AlphaXSupport.supported;
    final unknown = support == AlphaXSupport.unknown;
    final color = supported
        ? WaypointColors.mint
        : unknown
        ? WaypointColors.peach
        : WaypointColors.line;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.55),
        borderRadius: const BorderRadius.all(Radius.circular(13)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            supported
                ? Icons.check_rounded
                : unknown
                ? Icons.help_outline_rounded
                : Icons.remove_rounded,
            size: 16,
            color: WaypointColors.ink,
          ),
          const SizedBox(width: 7),
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(width: 5),
          Text(
            support.name,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
