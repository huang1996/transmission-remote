#!/usr/bin/env node
/**
 * Regenerates the sample application's resources.
 *
 * Two things are easy to get wrong by hand and expensive to debug on device:
 *
 * 1. **Light/dark colour parity.** A missing key in `resources/dark` silently
 *    falls back to the light value, which looks like a styling bug rather than a
 *    missing resource. Both palettes are therefore emitted from one table.
 * 2. **Locale parity.** An English string with no `zh_CN` counterpart shows up
 *    in the wrong language. Both locales are emitted from one table too.
 *
 * Usage:
 *   node scripts/generate-app-resources.mjs
 *
 * `scripts/lint-arkts.mjs` verifies that every `$r('app.color.*')` and
 * `$r('app.string.*')` used in an `.ets` file exists here.
 */
import fs from 'node:fs';
import path from 'node:path';

const REPO_ROOT = path.resolve(import.meta.dirname, '..');
const RES = path.join(REPO_ROOT, 'entry', 'src', 'main', 'resources');

/**
 * Semantic colour tokens as `[light, dark]`.
 *
 * Names describe a role, never a colour, so the palettes can be re-themed
 * without touching a single component.
 */
const COLORS = [
  ['app_background', '#F2F3F5', '#12171F'],
  ['surface', '#FFFFFF', '#1B222D'],
  ['surface_alt', '#F7F8FA', '#222B38'],
  ['surface_pressed', '#ECEEF1', '#26303E'],
  ['drawer_background', '#FFFFFF', '#171E28'],
  ['text_primary', '#182431', '#E7ECF3'],
  ['text_secondary', '#6B7480', '#98A2B3'],
  ['text_tertiary', '#9AA2AD', '#6B7684'],
  ['text_on_accent', '#FFFFFF', '#FFFFFF'],
  ['divider', '#E4E7EC', '#2A3441'],
  ['accent', '#2E6FF2', '#4C8DFF'],
  ['accent_soft', '#E8EFFD', '#1E2C44'],
  ['icon', '#6B7480', '#98A2B3'],
  ['icon_active', '#2E6FF2', '#4C8DFF'],
  ['success', '#2FA35C', '#3DD68C'],
  ['warning', '#E08A00', '#FFB020'],
  ['danger', '#DB3B3B', '#FF6B6B'],
  ['progress_track', '#E4E7EC', '#2A3441'],
  ['progress_fill', '#2E6FF2', '#4C8DFF'],
  ['progress_fill_done', '#2FA35C', '#3DD68C'],
  ['progress_fill_error', '#DB3B3B', '#FF6B6B'],
  ['progress_fill_verify', '#EF9F27', '#FFB020'],
  ['scrim', '#66000000', '#99000000'],
  ['fab_background', '#2E6FF2', '#4C8DFF'],
  ['fab_label_background', '#FFFFFF', '#2A3441'],
  ['selected_row', '#E8EFFD', '#1E2C44'],
  ['start_window_background', '#FFFFFF', '#12171F'],
  ['bottom_bar_background', '#FFFFFF', '#171E28'],
  ['top_bar_background', '#FFFFFF', '#171E28'],
];

/** User-visible strings as `[key, english, chinese]`. */
const STRINGS = [
  // --- module manifest -----------------------------------------------------
  // Referenced by module.json5; removing them breaks the build, so they are
  // part of the generated catalogue rather than hand-written JSON.
  ['module_desc', 'Transmission client', 'Transmission 客户端'],
  ['EntryAbility_desc', 'Transmission client', 'Transmission 客户端'],
  ['EntryAbility_label', 'TransmissionRemote', 'TransmissionRemote'],

  // --- generic -------------------------------------------------------------
  ['common_ok', 'OK', '确定'],
  ['common_cancel', 'Cancel', '取消'],
  ['common_save', 'Save', '保存'],
  ['common_delete', 'Delete', '删除'],
  ['common_remove', 'Remove', '移除'],
  ['common_edit', 'Edit', '编辑'],
  ['common_add', 'Add', '添加'],
  ['common_close', 'Close', '关闭'],
  ['common_retry', 'Retry', '重试'],
  ['common_rename', 'Rename', '重命名'],
  ['common_search', 'Search', '搜索'],
  ['common_none', 'None', '无'],
  ['common_unknown', 'Unknown', '未知'],
  ['common_enabled', 'Enabled', '已启用'],
  ['common_disabled', 'Disabled', '已禁用'],
  ['common_all', 'All', '全部'],
  ['common_colon', ':', '：'],

  // --- navigation ----------------------------------------------------------
  ['page_title_torrents', 'Torrents', '种子列表'],
  ['page_title_detail', 'Torrent details', '种子详情'],
  ['page_title_add', 'Add torrent', '添加种子'],
  ['page_title_servers', 'Servers', '服务器'],
  ['page_title_settings', 'Options', '选项'],
  ['page_title_about', 'About', '关于'],
  ['page_title_server_edit', 'Server', '服务器'],

  // --- drawer --------------------------------------------------------------
  ['drawer_servers', 'Servers', '服务器'],
  ['drawer_add_server', 'Add server', '添加服务器'],
  ['drawer_manage_servers', 'Manage servers', '管理服务器'],
  ['drawer_filter', 'Filter', '筛选'],
  ['drawer_sort', 'Sort by', '排序方式'],
  ['drawer_night_mode', 'Night mode', '夜间模式'],
  ['drawer_settings', 'Options', '设置'],
  ['drawer_about', 'About', '关于'],
  ['drawer_free_space', 'Free space', '可用空间'],
  ['drawer_sort_ascending', 'Ascending', '升序'],
  ['drawer_sort_descending', 'Descending', '降序'],

  // --- filters -------------------------------------------------------------
  ['filter_all', 'All', '全部'],
  ['filter_active', 'Active', '活跃'],
  ['filter_downloading', 'Downloading', '下载中'],
  ['filter_seeding', 'Seeding', '做种中'],
  ['filter_paused', 'Paused', '已暂停'],
  ['filter_downloaded', 'Downloaded', '已下载'],
  ['filter_completed', 'Completed', '已完成'],

  // --- sort keys -----------------------------------------------------------
  ['sort_queue', 'Queue order', '队列顺序'],
  ['sort_activity', 'Activity', 'Activity'],
  ['sort_added_date', 'Date added', '添加日期'],
  ['sort_last_activity', 'Last activity', '最后活动'],
  ['sort_name', 'Name', '名称'],
  ['sort_progress', 'Progress', '进度'],
  ['sort_size', 'Size', '大小'],
  ['sort_state', 'State', 'State'],
  ['sort_eta', 'Time remaining', '剩余时间'],
  ['sort_ratio', 'Ratio', '分享率'],
  ['sort_download_speed', 'Download speed', '下载速度'],
  ['sort_upload_speed', 'Upload speed', '上传速度'],

  // --- torrent list --------------------------------------------------------
  ['list_empty', 'No torrents', '暂无种子'],
  ['list_empty_filtered', 'Nothing matches this filter', '没有符合筛选条件的种子'],
  ['list_swipe_start', 'Resume', '开始'],
  ['list_swipe_pause', 'Pause', '暂停'],
  ['list_swipe_verify', 'Verify', '校验'],
  ['list_swipe_reannounce', 'Re-announce', '重新汇报'],
  ['list_swipe_remove', 'Remove', '移除'],
  ['list_swipe_delete', 'Delete data', '删除数据'],
  ['list_swipe_edit', 'Edit', '编辑'],
  ['list_verify_requested', 'Verification requested', '已请求校验'],
  ['list_reannounce_requested', 'Re-announce requested', '已请求重新汇报'],
  ['list_remove_confirm_title', 'Remove torrent?', '移除种子？'],
  ['list_remove_confirm_message', 'The downloaded files are kept.', '已下载的文件会被保留。'],
  ['list_delete_confirm_title', 'Remove and delete data?', '移除并删除数据？'],
  ['list_delete_confirm_message', 'The downloaded files will be deleted from the server.', '已下载的文件将从服务器上删除。'],

  // --- torrent state labels ------------------------------------------------
  ['state_stopped', 'Paused', '已暂停'],
  ['state_queued_verify', 'Queued to verify', '等待校验'],
  ['state_verifying', 'Verifying', '校验中'],
  ['state_queued_download', 'Queued', '排队中'],
  ['state_downloading', 'Downloading', '下载中'],
  ['state_queued_seed', 'Queued to seed', '等待做种'],
  ['state_seeding', 'Seeding', '做种中'],
  ['state_finished', 'Finished', '已完成'],
  ['state_error', 'Error', '错误'],
  ['state_verifying_progress', 'Checking existing data (%s)', '正在检查已存在的数据（%s）'],
  ['state_downloading_progress', 'Downloading data (%s)', '正在下载数据（%s）'],
  ['list_uploaded_ratio', '%s (ratio: %s)', '%s（分享率：%s）'],

  // --- detail: tabs --------------------------------------------------------
  ['detail_tab_info', 'Info', '信息'],
  ['detail_tab_files', 'Files', '文件'],
  ['detail_tab_trackers', 'Trackers', '服务器'],
  ['detail_tab_peers', 'Peers', '节点'],
  ['detail_tab_options', 'Options', '选项'],

  // --- detail: info fields -------------------------------------------------
  ['detail_field_hash', 'Hash', '哈希'],
  ['detail_field_uploaded', 'Uploaded', '已上传'],
  ['detail_field_eta', 'Time remaining', '剩余时间'],
  ['detail_field_location', 'Location', '位置'],
  ['detail_field_added', 'Added', '添加时间'],
  ['detail_field_created', 'Created', '创建时间'],
  ['detail_field_started', 'Started', '开始时间'],
  ['detail_field_finished', 'Finished', '完成时间'],
  ['detail_field_last_activity', 'Last activity', '最后活动'],
  ['detail_field_creator', 'Creator', '创建者'],
  ['detail_field_comment', 'Comment', '注释'],
  ['detail_field_privacy', 'Private torrent', '私有种子'],
  ['detail_field_public', 'Public torrent', '公开种子'],
  ['detail_field_peers', 'Peers', '节点'],
  ['detail_field_trackers', 'Trackers', '服务器'],
  ['detail_field_error', 'Error', '错误'],
  ['detail_field_group', 'Bandwidth group', '带宽组'],
  ['detail_field_labels', 'Labels', '标签'],

  // --- detail: info sections ------------------------------------------------
  // The Info tab is a set of definition lists, one per section, so each group
  // needs a heading of its own.
  ['info_section_torrent', 'Torrent', '种子信息'],
  ['info_section_transfer', 'Transfer', '传输'],
  ['info_section_dates', 'Dates', '日期'],
  ['info_section_runtime', 'Runtime', '运行时间'],
  ['info_field_total_size', 'Total size', '总计大小'],
  ['info_field_total_downloaded', 'Total downloaded', '总计下载'],
  ['info_field_average_speed', 'Average speed', '平均速度'],
  ['info_field_current_speed', 'Current speed', '当前速度'],
  ['info_field_availability', 'Availability', '可用'],
  ['info_field_magnet', 'Magnet', 'Magnet'],
  ['info_runtime_downloaded', 'Downloading', '下载'],
  ['info_runtime_seeded', 'Seeding', '做种'],
  ['info_size_with_pieces', '%s (%s pieces of %s)', '%s（%s 个 %s 的块）'],
  ['info_downloaded_with_percent', '%s (%s)', '%s（%s）'],
  ['info_uploaded_with_ratio', '%s (ratio: %s)', '%s（分享率：%s）'],

  // --- detail: action menu ---------------------------------------------------
  ['action_start', 'Resume', '开始'],
  ['action_pause', 'Pause', '暂停'],
  ['action_verify', 'Verify local data', '校验本地数据'],
  ['action_reannounce', 'Ask for more peers', '寻求更多节点'],
  ['action_rename', 'Rename', '重命名'],
  ['action_set_location', 'Set location', '设置保存位置'],
  ['action_share', 'Share torrent', '分享种子'],
  ['action_remove', 'Remove torrent', '删除种子'],
  ['action_rename_hint', 'New name', '新名称'],
  ['action_rename_empty', 'Enter a name', '请输入名称'],
  ['action_location_hint', '/downloads/music', '/downloads/music'],
  ['action_location_empty', 'Enter a path', '请输入路径'],
  ['action_location_move', 'Also move the downloaded files', '同时移动已下载的文件'],
  ['action_share_failed', 'Could not open the share sheet', '无法打开分享面板'],
  ['action_requested', 'Requested', '已提交'],

  // --- detail: files -------------------------------------------------------
  ['files_progress', '%s of %s (%s)', '%s / %s（%s）'],

  // --- detail: trackers ----------------------------------------------------
  ['trackers_last_update', 'Last update', '最后更新'],
  ['trackers_next_update', 'Next update in', '下一次更新于'],
  ['trackers_last_scrape', 'Last scrape', '最后刮擦'],
  ['trackers_seeds', 'Seeds', '种子'],
  ['trackers_peers', 'Peers', '下载'],
  ['trackers_downloaded', 'Downloaded', '已下载'],
  ['trackers_level', 'Tier %s', '层级 %s'],
  ['trackers_announce_state', 'Announce', '汇报'],
  ['trackers_scrape_state', 'Scrape', '抓取'],
  ['trackers_state_inactive', 'Idle', '空闲'],
  ['trackers_state_waiting', 'Waiting', '等待中'],
  ['trackers_state_queued', 'Queued', '排队中'],
  ['trackers_state_active', 'Active', '活跃'],

  // --- detail: peers -------------------------------------------------------
  ['peers_address', 'Address', '地址'],
  ['peers_client', 'Client', '客户端'],
  ['peers_progress', 'Progress', '进度'],
  ['peers_down', 'Down', '下载'],
  ['peers_up', 'Up', '上传'],
  ['peers_flags', 'Flags', '标志'],
  ['peers_encrypted', 'Encrypted', '已加密'],
  ['peers_incoming', 'Incoming', '主动连接'],

  // --- detail: options -----------------------------------------------------
  ['options_transfer', 'Transfer', '传输'],
  ['options_download_limit', 'Download limit', '下载限速'],
  ['options_upload_limit', 'Upload limit', '上传限速'],
  // 单位不翻译：Transmission 的 downloadLimit / uploadLimit 一律以 KB/s 计，
  // 缩写在各语言里都是同一个写法，译成「千字节/秒」反而对不上服务端的数字。
  ['options_speed_unit', 'KB/s', 'KB/s'],
  ['options_priority', 'Priority', '优先级'],
  ['options_priority_low', 'Low', '低'],
  ['options_priority_normal', 'Normal', '普通'],
  ['options_priority_high', 'High', '高'],
  ['options_sequential', 'Sequential download', '顺序下载'],
  ['options_seeding', 'Seeding', '做种'],
  ['options_ratio_mode', 'Ratio limit', '分享率限制'],
  ['options_ratio_limit', 'Ratio value', '分享率数值'],
  ['options_idle_mode', 'Idle limit', '闲置限制'],
  ['options_idle_limit', 'Idle minutes', '闲置分钟数'],
  ['options_mode_global', 'Use global', '使用全局设置'],
  ['options_mode_single', 'Custom', '自定义'],
  ['options_mode_unlimited', 'Unlimited', '不限制'],
  ['options_other', 'Other', '其他'],
  ['options_queue_position', 'Queue position', '队列位置'],
  ['options_peer_limit', 'Peer limit', '连接数上限'],
  ['options_group', 'Bandwidth group', '带宽组'],
  ['options_labels', 'Labels', '标签'],
  ['options_labels_hint', 'Separate labels with commas', '多个标签用逗号分隔'],
  ['options_saved', 'Saved', '已保存'],

  // --- add torrent ---------------------------------------------------------
  ['add_method', 'Method', '添加方式'],
  ['add_method_link', 'Link', '链接'],
  ['add_method_file', 'File', '文件'],
  ['add_link_hint', 'magnet: or https://…/file.torrent', 'magnet: 或 https://…/file.torrent'],
  ['add_pick_file', 'Choose a .torrent file', '选择 .torrent 文件'],
  ['add_no_file', 'No file selected', '未选择文件'],
  ['add_download_dir', 'Download to', '下载到'],
  ['add_download_dir_hint', 'Leave empty for the server default', '留空则使用服务器默认目录'],
  ['add_start_paused', 'Add paused', '添加后暂停'],
  ['add_submit', 'Add', '添加'],
  ['add_result_added', 'Torrent added', '种子已添加'],
  ['add_result_duplicate', 'Already in the list', '列表中已存在'],
  ['add_need_input', 'Enter a link or choose a file', '请输入链接或选择文件'],
  ['add_files_title', 'Files to download', '要下载的文件'],
  ['add_files_selected', 'Selected %s of %s (%s)', '已选 %s / %s 个文件（%s）'],
  ['add_files_none', 'Select at least one file', '请至少勾选一个文件'],
  ['add_files_invalid', 'Not a valid .torrent file', '不是有效的 .torrent 文件'],

  // --- servers -------------------------------------------------------------
  ['servers_empty', 'No servers yet', '还没有服务器'],
  ['servers_empty_hint', 'Add one to get started', '添加一个服务器开始使用'],
  ['servers_name', 'Name', '名称'],
  ['servers_name_hint', 'e.g. NAS', '例如：NAS'],
  ['servers_host', 'Host', '主机'],
  ['servers_host_hint', 'IP address or host name', 'IP 地址或域名'],
  ['servers_port', 'Port', '端口'],
  ['servers_path', 'RPC path', 'RPC 路径'],
  ['servers_path_hint', '/transmission/rpc', '/transmission/rpc'],
  ['servers_secure', 'Use HTTPS', '使用 HTTPS'],
  ['servers_secure_desc', 'Encrypt the connection to the server', '与服务器之间的连接将加密'],
  ['servers_username', 'User name', '用户名'],
  ['servers_username_hint', 'Optional', '可选'],
  ['servers_password', 'Password', '密码'],
  ['servers_password_hint', 'Optional', '可选'],
  ['servers_test', 'Test connection', '测试连接'],
  ['servers_testing', 'Testing…', '测试中…'],
  ['servers_test_ok', 'Connected', '连接成功'],
  ['servers_delete_confirm', 'Delete this server?', '删除该服务器？'],
  ['servers_invalid_host', 'Enter a host name or IP address', '请输入主机名或 IP 地址'],
  ['servers_invalid_port', 'Port must be between 1 and 65535', '端口必须在 1 到 65535 之间'],

  // --- multi-selection -----------------------------------------------------
  ['selection_count', 'Selected: %s', '已选 %s 项'],
  ['selection_select_all', 'Select all', '全选'],

  // --- settings ------------------------------------------------------------
  ['settings_theme', 'Appearance', '外观'],
  ['settings_theme_system', 'Follow system', '跟随系统'],
  ['settings_theme_light', 'Light', '浅色'],
  ['settings_theme_dark', 'Dark', '深色'],
  ['settings_refresh', 'Refresh interval', '更新间隔'],
  ['settings_refresh_desc', 'How often the torrent list is reloaded', '种子列表更新间隔'],
  ['settings_refresh_off', 'Manual only', '仅手动'],
  ['settings_notifications', 'Notifications', '通知'],
  ['settings_notifications_desc', 'Notify when a torrent finishes', '种子完成通知'],
  ['settings_show_fab', 'Show the add button', '显示“添加种子”浮动按钮'],
  ['settings_show_fab_desc', 'Floating button on the torrent list', '种子列表右下角的浮动按钮'],
  ['settings_advanced', 'Advanced', '高级'],
  ['settings_advanced_desc', 'Connection and protocol tuning', '连接与协议调整'],
  ['settings_timeout', 'Request timeout', '请求超时'],
  ['settings_timeout_desc', 'Seconds before a request is abandoned', '请求超时时间（秒）'],
  ['settings_api_style', 'API dialect', '接口协议'],
  ['settings_api_style_desc', 'Change only if auto-detection misbehaves', '仅在自动识别异常时修改'],
  ['settings_api_style_auto', 'Auto detect', '自动识别'],
  ['settings_api_style_modern', 'JSON-RPC (4.1.0+)', 'JSON-RPC（4.1.0+）'],
  ['settings_api_style_legacy', 'Legacy (< 4.1.0)', '旧版（< 4.1.0）'],
  ['settings_section_general', 'General', '通用'],
  ['settings_section_connection', 'Connection', '连接'],

  // --- status / errors -----------------------------------------------------
  ['status_not_connected', 'Not connected', '未连接'],
  ['status_connecting', 'Connecting…', '连接中…'],
  ['status_no_server', 'Add a server to begin', '请先添加服务器'],
  ['status_disconnected', 'Disconnected', '已断开'],
  ['error_network', 'Cannot reach the server', '无法连接服务器'],
  ['error_auth', 'Authentication failed', '认证失败'],
  ['error_timeout', 'The server did not answer in time', '服务器响应超时'],
  ['error_protocol', 'Unexpected server response', '服务器响应异常'],
  ['error_config', 'Invalid configuration', '配置无效'],
  ['error_unsupported', 'Not supported by this server', '服务器不支持该操作'],

  // --- notifications -------------------------------------------------------
  ['notification_channel', 'Torrent finished', '种子完成'],
  ['notification_done_title', 'Download finished', '下载完成'],

  // --- about ---------------------------------------------------------------
  ['about_version', 'Version %s (%s)', '版本 %s（%s）'],
  ['about_intro_title', 'What this is', '简介'],
  [
    'about_intro',
    'A remote control for the Transmission BitTorrent daemon, written for HarmonyOS. '
      + 'It talks to the daemon directly over its RPC interface — there is no cloud service '
      + 'in between, and no account to create.',
    '一个 HarmonyOS 上的 Transmission 远程控制客户端。它通过 RPC 接口直接连接守护进程，'
      + '中间没有云端服务，也不需要注册任何账号。',
  ],
  ['about_features_title', 'Features', '功能'],
  ['about_feature_torrents', 'Torrents', '种子管理'],
  [
    'about_feature_torrents_desc',
    'Start, pause, verify, re-announce or remove; batch commands via multi-select',
    '开始、暂停、校验、重新汇报、移除；长按进入多选后批量操作',
  ],
  ['about_feature_files', 'Selective download', '选择性下载'],
  [
    'about_feature_files_desc',
    'Pick which files to download; finished files are locked',
    '按文件选择要下载的内容；已下载完成的文件会被锁定',
  ],
  ['about_feature_detail', 'Details', '详情'],
  [
    'about_feature_detail_desc',
    'Peers, trackers, per-torrent limits, seeding rules and a file browser',
    '节点、Tracker、单种限速、做种规则与文件浏览',
  ],
  ['about_feature_servers', 'Servers', '服务器'],
  [
    'about_feature_servers_desc',
    'Keep several daemons and switch between them',
    '保存多个守护进程并在其间切换',
  ],
  ['about_feature_appearance', 'Appearance', '外观'],
  [
    'about_feature_appearance_desc',
    'Light and dark palettes, following the system or pinned by hand',
    '明暗两套配色，可跟随系统或手动指定',
  ],
  ['about_compat_title', 'Compatibility', '兼容性'],
  [
    'about_compat_rpc',
    'Speaks both the modern JSON-RPC 2.0 API (Transmission 4.1 and newer) and the legacy '
      + 'bespoke API, so older daemons work without changes.',
    '同时支持现代的 JSON-RPC 2.0 接口（Transmission 4.1 及更新）与早期的私有接口，'
      + '旧版守护进程无需改动即可使用。',
  ],
  [
    'about_compat_platform',
    'Requires HarmonyOS 5.0 (API 12) or newer; built with the Stage model.',
    '需要 HarmonyOS 5.0（API 12）或更高版本，基于 Stage 模型构建。',
  ],
  ['about_license_title', 'License', '开源许可'],
  ['about_license_value', 'GPL-2.0-only OR GPL-3.0-only', 'GPL-2.0-only OR GPL-3.0-only'],
  [
    'about_license_note',
    'Distributed under the same dual licence as the Transmission project it talks to. A few '
      + 'constant tables are generated from the Transmission source tree, which is why the '
      + 'licence carries over.',
    '与它所通信的 Transmission 项目采用同一套双许可。部分常量表由 Transmission 源码树生成，'
      + '这也是许可随之沿用下来的原因。',
  ],
  ['about_build_title', 'Build', '构建信息'],
  ['about_build_package', 'Bundle name', '包名'],
  ['about_build_version', 'Version', '版本'],
  ['about_build_version_code', 'Version code', '版本号'],
  ['about_build_target', 'Target API', '目标 API'],
  ['about_copyright', '© TransmissionRemote contributors', '© TransmissionRemote contributors'],
];

const LIGHT = new Map(COLORS.map(([name, light]) => [name, light]));
const DARK = new Map(COLORS.map(([name, , dark]) => [name, dark]));

function writeColors(dir, table, header) {
  const body = {
    color: [...table.entries()].map(([name, value]) => ({ name, value })),
  };
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, 'color.json'), `${JSON.stringify(body, null, 2)}\n`);
  return `${path.relative(REPO_ROOT, path.join(dir, 'color.json'))} (${header}, ${table.size} tokens)`;
}

function writeStrings(dir, index, header) {
  const body = {
    string: STRINGS.map((entry) => ({ name: entry[0], value: entry[index] })),
  };
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, 'string.json'), `${JSON.stringify(body, null, 2)}\n`);
  return `${path.relative(REPO_ROOT, path.join(dir, 'string.json'))} (${header}, ${STRINGS.length} strings)`;
}

// Guard against duplicate keys, which would silently shadow each other.
for (const [label, list] of [
  ['COLORS', COLORS],
  ['STRINGS', STRINGS],
]) {
  const seen = new Set();
  for (const entry of list) {
    if (seen.has(entry[0])) throw new Error(`${label}: duplicate key "${entry[0]}"`);
    seen.add(entry[0]);
  }
}

const written = [
  writeColors(path.join(RES, 'base', 'element'), LIGHT, 'light'),
  writeColors(path.join(RES, 'dark', 'element'), DARK, 'dark'),
  writeStrings(path.join(RES, 'base', 'element'), 1, 'en'),
  writeStrings(path.join(RES, 'zh_CN', 'element'), 2, 'zh'),
];

for (const line of written) console.log(`wrote ${line}`);
