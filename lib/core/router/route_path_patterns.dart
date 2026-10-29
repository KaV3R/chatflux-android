const Set<String> kGuildSettingsPathSegments = {
  'overview',
  'moderation',
  'audit-log',
  'bans',
  'members',
  'invites',
  'webhooks',
  'discovery',
  'channels',
  'roles',
  'emoji',
  'stickers',
};

const Set<String> kChannelSettingsPathSegments = {
  'overview',
  'permissions',
  'invites',
  'webhooks',
};

final RegExp kDmCallAppPath = RegExp(r'^/channels/@me/[^/]+/call$');
final RegExp kDmChannelAppPath = RegExp(r'^/channels/@me/[^/]+$');
final RegExp kDmMessageAppPath = RegExp(r'^/channels/@me/[^/]+/[^/]+$');
final RegExp kFavoritesChannelAppPath = RegExp(r'^/channels/@favorites/[^/]+$');
final RegExp kFavoritesMessageAppPath = RegExp(
  r'^/channels/@favorites/[^/]+/[^/]+$',
);
final RegExp kGuildMembersAppPath = RegExp(r'^/channels/[^@/][^/]*/members$');
final RegExp kGuildRootAppPath = RegExp(r'^/channels/[^@/][^/]*$');
final RegExp kGuildChannelAppPath = RegExp(r'^/channels/[^@/][^/]*/[^/]+$');
final RegExp kGuildMessageAppPath = RegExp(
  r'^/channels/[^@/][^/]*/[^/]+/[^/]+$',
);
