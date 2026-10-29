import 'dart:convert';

import 'package:fluxer_app/core/database/fluxer_database.dart' as db;
import 'package:fluxer_app/core/permissions/channel_permission_resolver.dart';
import 'package:fluxer_app/core/permissions/permission.dart';
import 'package:fluxer_app/features/channels/data/read_state_utils.dart';
import 'package:fluxer_app/features/members/domain/member.dart';

class ChannelUnreadPermissionOutcome {
  const ChannelUnreadPermissionOutcome({
    required this.canRead,
    required this.isDefinitive,
  });

  final bool canRead;
  final bool isDefinitive;
}

Future<ChannelUnreadPermissionOutcome> evaluateChannelUnreadPermission({
  required db.FluxerDatabase database,
  required db.Channel channel,
  required String? currentUserId,
}) async {
  if (currentUserId == null || currentUserId.isEmpty) {
    return const ChannelUnreadPermissionOutcome(
      canRead: true,
      isDefinitive: true,
    );
  }
  final guild = await database.guildDao.getServerById(channel.guildId);
  if (guild == null) {
    return const ChannelUnreadPermissionOutcome(
      canRead: true,
      isDefinitive: false,
    );
  }
  if (guild.ownerId == currentUserId) {
    return const ChannelUnreadPermissionOutcome(
      canRead: true,
      isDefinitive: true,
    );
  }

  final member = await database.memberDao.getMemberByUserId(
    currentUserId,
    channel.guildId,
  );
  if (member == null) {
    return const ChannelUnreadPermissionOutcome(
      canRead: true,
      isDefinitive: false,
    );
  }

  final roles = await database.roleDao.getRoles(channel.guildId);
  final memberRoleIds = member.roleIdsJson.isNotEmpty
      ? List<String>.from(jsonDecode(member.roleIdsJson) as List<dynamic>)
      : <String>[];
  final everyoneRole = roles
      .where((role) => role.id == channel.guildId)
      .firstOrNull;
  if (everyoneRole == null && roles.isEmpty) {
    return const ChannelUnreadPermissionOutcome(
      canRead: true,
      isDefinitive: true,
    );
  }
  final everyonePermissions =
      int.tryParse(everyoneRole?.permissions ?? '0') ?? 0;
  final memberRoles = roles
      .where((role) => memberRoleIds.contains(role.id))
      .map(MemberRole.fromRow)
      .toList();
  final layers = await database.channelDao.getPermissionOverwriteLayers(
    channel.id,
  );
  final bits = evaluateChannelEffectivePermissionBits(
    guildOwnerId: guild.ownerId ?? '',
    guildId: channel.guildId,
    currentUserId: currentUserId,
    everyonePermissions: everyonePermissions,
    memberRoles: memberRoles,
    memberRecordPresent: true,
    overwriteJsonLayersRootToLeaf: layers,
  );
  return ChannelUnreadPermissionOutcome(
    canRead: hasPermission(bits, Permission.viewChannel),
    isDefinitive: true,
  );
}

List<String?> permissionOverwriteLayersFromSnapshot(
  db.Channel channel,
  Map<String, db.Channel> snapshot,
) {
  final List<db.Channel> bottomUp = <db.Channel>[];
  String? currentId = channel.id;
  while (currentId != null) {
    final db.Channel? row = snapshot[currentId];
    if (row == null) {
      break;
    }
    bottomUp.add(row);
    currentId = row.parentId;
  }
  return <String?>[
    for (final db.Channel row in bottomUp.reversed)
      row.permissionOverwritesJson,
  ];
}

class ChannelUnreadPermissionSeedCache {
  ChannelUnreadPermissionSeedCache(this.byChannelId);

  final Map<String, ChannelUnreadPermissionOutcome> byChannelId;

  bool canReadForUnread(db.Channel channel) {
    final ChannelUnreadPermissionOutcome? outcome = byChannelId[channel.id];
    if (outcome == null || !outcome.isDefinitive) {
      return true;
    }
    return outcome.canRead;
  }
}

Future<ChannelUnreadPermissionSeedCache> buildChannelUnreadPermissionSeedCache({
  required db.FluxerDatabase database,
  required String? currentUserId,
  required Iterable<db.Channel> channels,
  required List<db.Server> guilds,
  required Map<String, db.Channel> channelSnapshot,
}) async {
  final Map<String, ChannelUnreadPermissionOutcome> byChannelId =
      <String, ChannelUnreadPermissionOutcome>{};
  if (currentUserId == null || currentUserId.isEmpty) {
    for (final db.Channel channel in channels) {
      byChannelId[channel.id] = const ChannelUnreadPermissionOutcome(
        canRead: true,
        isDefinitive: true,
      );
    }
    return ChannelUnreadPermissionSeedCache(byChannelId);
  }

  final Map<String, db.Server> guildById = <String, db.Server>{
    for (final db.Server guild in guilds) guild.id: guild,
  };
  final Set<String> guildIds = <String>{
    for (final db.Channel channel in channels)
      if (channel.guildId.isNotEmpty) channel.guildId,
  };
  final Map<String, db.Member?> membersByGuild = <String, db.Member?>{};
  final Map<String, List<db.Role>> rolesByGuild = <String, List<db.Role>>{};
  for (final String guildId in guildIds) {
    membersByGuild[guildId] = await database.memberDao.getMemberByUserId(
      currentUserId,
      guildId,
    );
    rolesByGuild[guildId] = await database.roleDao.getRoles(guildId);
  }

  for (final db.Channel channel in channels) {
    if (channel.guildId.isEmpty) {
      byChannelId[channel.id] = const ChannelUnreadPermissionOutcome(
        canRead: true,
        isDefinitive: true,
      );
      continue;
    }
    final db.Server? guild = guildById[channel.guildId];
    if (guild == null) {
      byChannelId[channel.id] = const ChannelUnreadPermissionOutcome(
        canRead: true,
        isDefinitive: false,
      );
      continue;
    }
    if (guild.ownerId == currentUserId) {
      byChannelId[channel.id] = const ChannelUnreadPermissionOutcome(
        canRead: true,
        isDefinitive: true,
      );
      continue;
    }
    final db.Member? member = membersByGuild[channel.guildId];
    if (member == null) {
      byChannelId[channel.id] = const ChannelUnreadPermissionOutcome(
        canRead: true,
        isDefinitive: false,
      );
      continue;
    }
    final List<db.Role> roles = rolesByGuild[channel.guildId] ?? const [];
    final List<String> memberRoleIds = member.roleIdsJson.isNotEmpty
        ? List<String>.from(jsonDecode(member.roleIdsJson) as List<dynamic>)
        : <String>[];
    final db.Role? everyoneRole = roles
        .where((db.Role role) => role.id == channel.guildId)
        .firstOrNull;
    if (everyoneRole == null && roles.isEmpty) {
      byChannelId[channel.id] = const ChannelUnreadPermissionOutcome(
        canRead: true,
        isDefinitive: true,
      );
      continue;
    }
    final int everyonePermissions =
        int.tryParse(everyoneRole?.permissions ?? '0') ?? 0;
    final List<MemberRole> memberRoles = roles
        .where((db.Role role) => memberRoleIds.contains(role.id))
        .map(MemberRole.fromRow)
        .toList();
    final List<String?> layers = permissionOverwriteLayersFromSnapshot(
      channel,
      channelSnapshot,
    );
    final int bits = evaluateChannelEffectivePermissionBits(
      guildOwnerId: guild.ownerId ?? '',
      guildId: channel.guildId,
      currentUserId: currentUserId,
      everyonePermissions: everyonePermissions,
      memberRoles: memberRoles,
      memberRecordPresent: true,
      overwriteJsonLayersRootToLeaf: layers,
    );
    byChannelId[channel.id] = ChannelUnreadPermissionOutcome(
      canRead: hasPermission(bits, Permission.viewChannel),
      isDefinitive: true,
    );
  }
  return ChannelUnreadPermissionSeedCache(byChannelId);
}

Future<bool> canReadChannelForUnread({
  required db.FluxerDatabase database,
  required db.Channel channel,
  required String? currentUserId,
}) async {
  final outcome = await evaluateChannelUnreadPermission(
    database: database,
    channel: channel,
    currentUserId: currentUserId,
  );
  if (!outcome.isDefinitive) {
    return true;
  }
  return outcome.canRead;
}

Future<int> guildChannelFallbackAckMs({
  required db.FluxerDatabase database,
  required db.Channel channel,
  required String? currentUserId,
}) async {
  if (currentUserId != null && currentUserId.isNotEmpty) {
    final member = await database.memberDao.getMemberByUserId(
      currentUserId,
      channel.guildId,
    );
    final joinedAt = member?.joinedAt;
    if (joinedAt != null) {
      return joinedAt.millisecondsSinceEpoch;
    }
  }
  return snowflakeTimestampMs(channel.id);
}
