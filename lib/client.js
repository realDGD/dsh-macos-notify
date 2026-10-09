/* dsh-macos-notify — Desktop/Web client (hand-written bundle, no build step).
 *
 * Desktop notification requests plus the legacy Web features below all end
 * in "jump to that session". Desktop uses the authenticated Connection API;
 * no HTTP page or external browser is opened by the Desktop path.
 *
 *  1) URL deep link — opening `http://127.0.0.1:3080/?session=<id>` selects
 *     that session once it appears in the session list, then strips the
 *     parameter (history.replaceState, no reload, no extra history entry).
 *
 *  2) Legacy browser notifications remain disabled by default. The standalone
 *     Host producer and DSH Notify.app own macOS reminders and interactions.
 *
 * Safety posture:
 *   - nothing happens unless there is something to do (URL param / hidden tab);
 *   - every step is guarded: a failure is silent and never breaks the page;
 *   - reads only the public `sessions` client service (list snapshot/subscribe,
 *     select) and the browser Notification API;
 *   - notification permission is only requested after a real user gesture;
 *   - notification click only focuses the window and selects a session.
 */
window.__ModuleLoader__.load({
  id: 'dsh-macos-notify',
  factory: (require) => {
    var module = { exports: {} };
    var exports = module.exports;

    /**
     * The services this plugin needs.
     *
     * `uiWorkspace` is what 0.1.7 selects a session through; `sessions` is
     * still declared because its list drives the deep-link and notification
     * logic, and because an older build provides navigation there instead.
     */
    var inject = ['sessions', 'uiWorkspace', 'connection', 'slots', 'locale'];
    // UI_LOCALES_START (generated from macos/assets/ui-strings.json)
    var uiStrings = {"允许一次":"Allow once","拒绝":"Reject","允许本次 (Allow)":"Allow once","拒绝 (Deny)":"Reject","查看详情":"View details","打开完整问答":"Open questions","等待回答":"Waiting for answer","等待审批":"Waiting for approval","出错":"Error","异常中断":"Interrupted","输出上限":"Output limit reached","进行中":"Running","已完成":"Completed","用户停止":"Stopped by user","已暂停":"Paused","状态未知":"Unknown status","随主会话停止":"Stopped with parent session","规则取消":"Canceled by rule","运行环境停止":"Environment stopped","停止原因未知":"Unknown stop reason","未分组":"Ungrouped","未命名":"Untitled","等待 DSH 连接":"Waiting for DSH to connect","DSH 未连接，内容可能过期":"DSH disconnected; information may be out of date","会话数据暂不可用，显示上次有效内容":"Session data is unavailable. Showing the last available information.","正在加载会话…":"Loading sessions…","DSH 已连接":"DSH connected","活动会话":"Active sessions","最近会话":"Recent sessions","活动会话列表":"Active session list","最近会话列表":"Recent session list","暂无本次连接的活动会话":"No active sessions since connecting","暂无最近会话":"No recent sessions","菜单栏设置":"Menu bar settings","DSH Notify 会话面板":"DSH Notify session panel","关闭菜单栏":"Disable menu bar","打开 DSH":"Open DSH","重新启用：DSH 设置 → DSH Notify":"Enable again in DSH Settings → DSH Notify","向上查看":"Show previous ","向下查看":"Show more ","查看上面的会话":"View earlier sessions","查看更多会话":"View more sessions","展开":"Expand ","展开更多":"Show more ","收起":"Collapse ","的子智能体":" subagents"," · 子智能体":" · Subagent: ","任务：":"Task: ","，已置顶":", Pinned","，子智能体":", Subagent: ","，任务 {0}/{1}":", Tasks {0}/{1}","任务 {0}/{1}":"Tasks {0}/{1}","第{0}层 · ":"Level {0} · ","另有 {0} 条，请在 DSH 查看":"{0} more sessions. Open DSH to view them.","处理请求":"Actions","处理请求（{0}）":"Actions ({0})","处理当前会话的审批或问答":"Respond to this session’s approval requests or questions","审批":"Approval","问答":"Questions","无文字输入":"No text input","请求暂不可用。":"This request is currently unavailable.","无法打开 DSH Desktop。":"Unable to open DSH Desktop.","请求已失效或正在提交，请等待连接和菜单刷新。":"This request has expired or is being submitted. Wait for DSH to connect and the menu to refresh.","未能发送菜单栏设置，请在 DSH 设置中重试。":"Couldn’t update the menu bar setting. Try again in DSH Settings.","DSH 未接受菜单栏设置，请重试。":"DSH didn’t accept the menu bar setting. Please try again.","未确认设置已保存，请检查 DSH 连接后重试。":"Couldn’t confirm that the setting was saved. Check the DSH connection and try again.","问题 {0}{1}":"Question {0}{1}","问题 {0} 的自定义答案":"Custom answer for question {0}","可选择多个选项，也可以补充文字":"Select one or more options. You can also add a custom answer.","可选择一个选项，也可以补充文字":"Select an option. You can also add a custom answer.","自定义答案／补充（可与选项一起提交）":"Custom answer or additional details (submitted with your selections)","查看相关上下文与会话信息":"View related context and session information","会话 ID：{0}":"Session ID: {0}","完整工具参数":"Full tool arguments","查看原文":"View original","复制原始参数":"Copy original arguments","提交全部回答":"Submit all answers","回到 DSH 会话":"Open in DSH"," · 审批详情":" · Approval details"," · 问答":" · Questions","请求原因\n{0}":"Reason\n{0}","复制完整命令":"Copy full command","待执行命令":"Command to run","完整待执行命令":"Full command to run","完整工具参数（含权限与工作目录设置）":"Full tool arguments (including permissions and working directory)","无法取得此请求的完整工具参数，请回到 DSH 核实后决定。":"Full tool arguments are unavailable. Review this request in DSH before deciding.","暂时无法连接 DSH，请恢复连接后处理。":"Can’t connect to DSH right now. Reconnect before responding.","请核实命令、参数和权限后决定。":"Review the command, arguments and permissions before deciding.","暂时无法连接 DSH，已保留草稿。恢复连接后可继续。":"DSH is disconnected. Your draft has been kept. Continue after reconnecting.","DSH 正在将问题转入后台，请稍候…":"DSH is moving these questions to the background. Please wait…","正在提交，请稍候…":"Submitting. Please wait…","正在打开目标 DSH 会话…":"Opening the target DSH session…","此请求已在 DSH 回答、取消或失效，无需再次提交。":"This request has been answered, canceled, or has expired in DSH. You don’t need to submit it again.","决定已提交，DSH 已接受。":"Decision submitted and accepted by DSH.","已提交全部回答。":"All answers submitted.","请求已回答或失效，本次没有重复提交。":"This request has already been answered or has expired. No duplicate response was sent.","问题正在转入后台，请稍后提交。":"These questions are moving to the background. Try submitting again in a moment.","提交未成功（{0}），请检查回答或回到 DSH。":"Submission failed ({0}). Check your answers or return to DSH.","未收到确认，请回到 DSH 核实结果。本助手不会自动重试。":"No confirmation received. Check the result in DSH. This helper won’t retry automatically.","请求已回答或失效。":"This request has been answered or has expired.","此请求正在提交，请等待 DSH 确认。":"This request is being submitted. Wait for confirmation from DSH.","请求已提交或失效。":"This request has been submitted or has expired.","无法提交：{0}。请回到 DSH 处理。":"Unable to submit: {0}. Continue in DSH.","请求已回答或失效，请等待菜单刷新。":"This request has been answered or has expired. Wait for the menu to refresh.","请求正在转入后台，请稍后重试。":"This request is moving to the background. Try again in a moment.","DSH · 请求处理提示":"DSH · Request status","未确认已打开目标会话，窗口已保留。请检查 DSH 后重试。":"Couldn’t confirm that the target session opened. This window remains open; check DSH and try again.","无法打开 DSH Desktop，窗口已保留。":"Unable to open DSH Desktop. This window remains open.","无法打开 DSH Desktop，请检查应用是否已安装。":"Unable to open DSH Desktop. Check that it is installed.","无法保存跳转请求，窗口已保留：{0}":"Unable to save the navigation request: {0}\nThis window remains open.","DSH Desktop 打开失败，窗口已保留：{0}":"Unable to open DSH Desktop: {0}\nThis window remains open.","关闭问答窗口":"Close question window","编辑":"Edit","撤销":"Undo","剪切":"Cut","复制":"Copy","粘贴":"Paste","全选":"Select all","上下文原文":"Original context","相关上下文 Markdown":"Related context Markdown","你的请求":"Your request","助手说明":"Assistant response","Markdown 显示暂不可用，以下为原文：\n\n":"Can’t display Markdown right now. Original text:\n\n","\n（较长内容显示前 20,000 字符，请回到 DSH 阅读全文。）":"\n(Only the first 20,000 characters are shown. Open DSH to read the full context.)","较长内容显示前 20,000 字符，请回到 DSH 阅读全文。":"Only the first 20,000 characters are shown. Open DSH to read the full context.","此请求没有可用的前置文字上下文。":"No earlier text context is available for this request.","图片：":"Image: ","未加载":"Not loaded","公式无法渲染，显示原文":"Couldn’t render the formula. Showing the source instead.","任务完成":"Task completed","任务出错":"Task failed","DSH Notify · 安全测试":"DSH Notify · Notification test","任务已完成，点击回到对应会话。":"Task completed. Click to return to this session.","任务遇到错误，点击回到 DSH 查看详情。":"The task encountered an error. Click to view details in DSH.","这是通知测试，不会执行命令或发送模型消息。":"This test does not run commands or send model messages.","需要回答 {0} 个问题":"Questions to answer: {0}","操作":"Action","请求批准":"Approval requested","DSH 未确认请求":"DSH did not confirm the request","无法连接 DSH，请重连后重试。":"Unable to connect to DSH. Reconnect and retry.","设置已保存":"Settings saved","保存未成功，请重试。":"Couldn’t save your changes. Please try again.","尚未进行安全测试":"Not tested yet","测试未排队，请检查助手":"The test notification wasn’t queued. Check that the helper is running.","已排队，等待助手":"Queued; waiting for the helper","已交给 macOS，等待点击通知":"Sent to macOS; waiting for you to click the notification","已点击，正在确认目标会话":"Notification clicked; confirming that the target session opened","已确认打开目标会话":"Target session opened","未确认跳转，请检查 DSH 后重试":"Couldn’t confirm that the session opened. Check DSH and try again.","macOS 未接受通知，请检查权限":"macOS didn’t accept the notification. Check notification permissions.","助手未确认收到测试，请检查后重试":"The helper hasn’t confirmed receipt of the test notification. Check that the helper is running and try again.","已允许":"Authorized","未允许，请在系统设置中允许 DSH Notify":"Not authorized. Allow DSH Notify in System Settings.","等待授权":"Awaiting permission","临时允许":"Provisionally authorized","未知":"Unknown","macOS 原生通知、审批和完整问答":"Native macOS notifications, approvals and question forms","提醒类型":"Notification types","需要审批":"Approval requests","需要回答问题":"Questions","提醒方式":"Notification behavior","播放系统提示音":"Play system sound","单独提醒子智能体结果":"Show separate notifications for subagent results","等待子智能体结束后汇总主任务完成":"Wait for subagents before reporting completion","正在前台查看对应会话时静默提醒":"Silence notifications while viewing the session","静默仅影响通知；已经打开的审批或问答面板始终保留。":"Quiet mode only affects notifications. Open approval and question windows remain available.","菜单栏":"Menu bar","启用菜单栏会话面板":"Enable the menu bar session panel","运行状态":"Status","插件版本 ":"Plugin version "," · DSH 已连接":" · DSH connected","DSH 状态暂不可用":"DSH status unavailable","助手运行中 · 版本 ":"Helper running · Version "," · 通知权限：":" · Notification permission: ","助手未运行或尚未安装":"The helper isn’t running or hasn’t been installed","插件与助手版本不同，请更新后正常重启 DSH。":"The plugin and helper versions don’t match. Update both and restart DSH.","安全测试：":"Notification test: ","状态暂不可用":"Status unavailable","已排队 ":"Queued "," · 已静默 ":" · Silenced "," · 等待子智能体 ":" · Waiting for subagents ","安全测试通知已排队，请实际点击通知核对会话。":"Test notification queued. Click it to check that the correct session opens.","测试未成功，请检查连接。":"Test failed. Check the connection.","发送安全测试通知":"Send test notification","安装、升级与故障排查":"Installation, upgrades and troubleshooting","需要你的操作":"Action needed","任务完成 — 点我回到会话":"Task completed — return to session","DSH 测试通知":"DSH test notification","点击应切到会话 ":"Click to switch to session ","会话 ":"Session ","会话 ID：":"Session ID: ","请求原因\n":"Reason\n","已回答 {0} / {1} · 每题至少选择一个选项或填写自定义答案":"Answered {0} / {1} · Select an option or enter a custom answer for each question"};
    // UI_LOCALES_END
    var uiLocale = 'en';
    function T(source, params) { return (uiLocale === 'zh' ? source : uiStrings[source] || source).replace(/\{(\d+)\}/g, function (m,k) { return params && Object.prototype.hasOwnProperty.call(params,k) ? String(params[k]) : m; }); }
    function applyUILanguage(ctx) {
      var locale, connection;
      try { locale=ctx.get('locale'); connection=ctx.get('connection'); } catch (_) { return; }
      if (!locale || typeof locale.getSnapshot !== 'function' || !connection) return;
      var clientId='view-'+Date.now().toString(36)+'-'+Math.random().toString(36).slice(2),seq=0,disposed=false,inflight=false,requested=false;
      var send=function () {
        if (disposed) return;
        try { uiLocale=/^zh(?:-|$)/i.test(locale.getSnapshot().active) ? 'zh' : 'en'; } catch (_) { return; }
        requested=true;
        if (inflight) return;
        inflight=true;requested=false;
        var packet={locale:uiLocale,clientId:clientId,seq:++seq};
        Promise.resolve().then(function () { if (!disposed) return connection.rpc.call('/api','dsh-macos-notify/locale',packet); })
          .catch(function () { requested=true; }).finally(function () { inflight=false; });
      };
      send();
      var off=locale.subscribe(send),reset=ctx.on && ctx.on('connection/reset',send);
      var timer=window.setInterval(function () { if (requested) send(); },1000);
      if (ctx.effect) ctx.effect(function () { return function () { disposed=true;off && off();reset && reset();window.clearInterval(timer); }; });
    }


    /**
     * 把某个会话变成当前主视图 —— 跨 DSH 版本、跨工作区都走对路。
     *
     * 版本差异（0.1.5-rc.2 → 0.1.7-rc.1），这是本插件唯一真正需要版本适配的地方：
     *
     *   · 0.1.5：视图选择在 sessions 服务上，`sessions.open(id)` 一步到位。
     *
     *   · 0.1.7：两处破坏性变更叠加。
     *     ① 视图选择搬到了 `uiWorkspace` 服务（sessions 服务的注释写得很明白：
     *        "view selection remains outside the Controller"），旧方法静默消失。
     *     ② 新增了**工作区**这一层：会话隶属于工作区，只有已连接的工作区才会
     *        在侧栏列出它的会话。
     *
     * 于是 0.1.7 上正确的一步其实是两步：
     *     ① 目标会话所属的工作区必须是**当前已连接**的那个 —— 否则会话视图会引用
     *        一个不属于当前工作区的会话，实测表现为**黑屏**或主视图空白；
     *     ② 再 openSession。
     * 侧栏切换工作区走的是同一条路：`uiWorkspace.openWorkspace(workspaceId)`。
     *
     * 每个分支都做能力探测而不是判版本号：0.1.7 删旧方法时是**静默**的，
     * 只有 typeof 保护才能让旧版本上的点击不抛异常。
     */
    var workspaceServiceOf = function (ctx) {
      try { return typeof ctx.get === 'function' ? ctx.get('uiWorkspace') : null; } catch (e) { return null; }
    };

    /**
     * 应用自己是否已完成初始导航（等价于"工作区已连接"）。
     *
     * 0.1.7 的 ui-workspace 启动协调器以 `mainReference` 为闸门：
     *   const reconcile = () => {
     *     if (initial !== "waiting") return;
     *     if (workspace.phase !== "ready" || sessions.phase !== "ready") return;
     *     if (this.mainReference !== void 0) { initial = "done"; return; }   // ★
     *     initial = "connecting";
     *     this.restoreSelection(workspace, sessions).then(...);              // ← 连接工作区
     *   };
     * ★ 只要 mainReference 非空就直接收工，而 restoreSelection 才是连接工作区那步。
     * 插件若抢在它前面 openSession，就会把 mainReference 提前设上 → 协调器判定
     * "已经有主视图了" → **永远跳过工作区连接**。实测症状：左栏只显示工作区、列不出
     * 会话，单击切换会话无效（双击却能打开重命名，弹出类菜单也正常）。
     *
     * `mainReference` 是公开类字段，正是协调器读的那一个，所以直接拿它当就绪信号，
     * 激活时机就和侧栏点击（必然发生在启动完成之后）完全一致。
     */
    var appNavigated = function (workspace) {
      if (!workspace) return false;
      try { return workspace.mainReference !== void 0 && workspace.mainReference !== null; } catch (e) { return false; }
    };

    /** 当前主视图是不是正好就是某个会话。 */
    var isCurrent = function (workspace, id) {
      if (!workspace) return false;
      try {
        var reference = workspace.mainReference;
        return reference !== void 0 && reference !== null && reference.sessionId === id;
      } catch (e) { return false; }
    };

    /** 会话所属的工作区 id；结构不认识时返回 null（当作"未知"，不阻断流程）。 */
    var ownerWorkspaceOf = function (workspace, id, sessions, lineage) {
      try {
        var snapshot = workspace.workspaces.list.getSnapshot();
        var items = (snapshot && snapshot.items) || [];
        var catalog = sessions && sessions.list.getSnapshot(), seen = new Set(), current = id;
        while (current && !seen.has(current)) {
          seen.add(current);
          for (var i = 0; i < items.length; i += 1) {
            if ((items[i].sessionIds || []).indexOf(current) !== -1) return items[i].workspaceId;
          }
          var entry = catalog && catalog.byId && catalog.byId[current];
          var address = sessions && typeof sessions.subagentAddress === 'function' && sessions.subagentAddress(current);
          current = entry && entry.parentId || address && address.parentSessionId;
        }
        if (Array.isArray(lineage) && lineage.length <= 2000 && lineage[lineage.length - 1] === id) {
          for (var j = 0; j < lineage.length; j += 1) {
            for (var k = 0; k < items.length; k += 1) {
              if ((items[k].sessionIds || []).indexOf(lineage[j]) !== -1) return items[k].workspaceId;
            }
          }
        }
      } catch (e) { /* 拿不到就当未知 */ }
      return null;
    };

    /** 当前已连接的工作区 id（由主视图反推）。 */
    var connectedWorkspaceOf = function (workspace, sessions) {
      try {
        var reference = workspace.mainReference;
        if (reference === void 0 || reference === null) return null;
        return ownerWorkspaceOf(workspace, reference.sessionId, sessions);
      } catch (e) { return null; }
    };

    /**
     * 当前主视图的会话 id。
     *
     * 跨版本取值：0.1.7 的列表快照**没有** `current` 字段了（视图选择移出了
     * sessions 服务），只能从 `uiWorkspace.mainReference` 反推；0.1.5 则相反。
     * 诊断钩子需要它，所以两条路都试。
     */
    var currentSessionIdOf = function (ctx, sessions) {
      var workspace = workspaceServiceOf(ctx);
      try {
        var reference = workspace && workspace.mainReference;
        if (reference !== void 0 && reference !== null && typeof reference.sessionId === 'string') return reference.sessionId;
      } catch (e) { /* 继续试旧路径 */ }
      try {
        var snapshot = sessions.list.getSnapshot();
        return typeof snapshot.current === 'string' ? snapshot.current : null;
      } catch (e) { return null; }
    };

    /**
     * 执行切换。
     * @returns {Promise<boolean>} 是否**确认**已切到目标会话（用应用自己的
     *   `mainReference` 复核，而不是"调用没抛异常"就算成功）。
     */
    var activateSession = function (ctx, id, address, lineage) {
      if (!ctx || typeof id !== 'string' || id === '') return Promise.resolve(false);
      var workspace = workspaceServiceOf(ctx);
      if (workspace && typeof workspace.openSession === 'function') {
        var sessionService = ctx.get('sessions');
        var owner = ownerWorkspaceOf(workspace, id, sessionService, lineage);
        var connected = connectedWorkspaceOf(workspace, sessionService);
        var crossWorkspace = owner !== null && connected !== null && owner !== connected
          && typeof workspace.openWorkspace === 'function';
        var pre = crossWorkspace
          ? Promise.resolve(workspace.openWorkspace(owner)).catch(function () { /* 连接失败就照常试一次 */ })
          : Promise.resolve();
        return pre.then(function () {
          try { workspace.openSession(address || id); } catch (e) { return false; }
          return isCurrent(workspace, id);
        });
      }
      // 0.1.5 及更早：视图选择还在 sessions 服务上。
      try {
        var sessions = typeof ctx.get === 'function' ? ctx.get('sessions') : null;
        if (sessions && typeof sessions.open === 'function') { sessions.open(id); return Promise.resolve(true); }
        if (sessions && typeof sessions.select === 'function') { sessions.select(id); return Promise.resolve(true); }
      } catch (e) { /* 调用失败不致命 */ }
      return Promise.resolve(false);
    };

    /** Give up on a deep link whose session never shows up. */
    var DEEPLINK_GIVE_UP_MS = 30000;

    /** 首次尝试前的宽限：侧栏点击总在启动完成之后，插件却在启动中途就跑起来了。 */
    var DEEPLINK_GRACE_MS = 600;

    /** 最多等应用自己的初始导航多久；超时后不再等待，照常尝试激活。 */
    var SETTLE_WAIT_MS = 8000;

    /** Desktop's dsh://open only focuses its window; select the clicked session here. */
    function applyDesktopJump(ctx, sessions) {
      if (window.location.protocol !== 'dsh-app:') return;
      var connection = ctx.get('connection');
      if (!connection || !connection.rpc || typeof connection.rpc.call !== 'function') return;
      var disposed = false;
      var busy = false;
      var selectedRequestId = null;
      var poll = function () {
        if (disposed || busy) return;
        busy = true;
        connection.rpc.call('/api', 'dsh-macos-notify/pending', {}).then(function (result) {
          var request = result && result.ok === true ? result.value : null;
          if (disposed || !request || typeof request.sessionId !== 'string' || typeof request.requestId !== 'string') return;
          var workspace = workspaceServiceOf(ctx);
          if (!appNavigated(workspace)) return;
          var acknowledge = function () {
            return connection.rpc.call('/api', 'dsh-macos-notify/ack', {
              requestId: request.requestId, sessionId: request.sessionId,
            });
          };
          if (selectedRequestId === request.requestId && isCurrent(workspace, request.sessionId)) return acknowledge();
          var snapshot = sessions.list.getSnapshot();
          var address = request.address;
          if (!address || address.childSessionId !== request.sessionId || typeof address.parentSessionId !== 'string'
            || !/^[A-Za-z0-9][A-Za-z0-9._-]{0,199}$/.test(address.parentSessionId) || ['unknown', 'one-shot', 'continuable'].indexOf(address.mode) === -1) address = null;
          if (((snapshot && snapshot.ids) || []).indexOf(request.sessionId) === -1
            && ownerWorkspaceOf(workspace, request.sessionId, sessions, address ? request.lineage : null) === null) return;
          return activateSession(ctx, request.sessionId, address, address ? request.lineage : null).then(function (ok) {
            if (disposed || ok !== true) return;
            selectedRequestId = request.requestId;
            return acknowledge();
          });
        }).catch(function () { /* Host boot/reconnection: retry on the next tick. */ })
          .then(function () { busy = false; });
      };
      var timer = window.setInterval(poll, 1000);
      window.addEventListener('focus', poll);
      if (typeof ctx.effect === 'function') ctx.effect(function () {
        return function () {
          disposed = true;
          window.clearInterval(timer);
          window.removeEventListener('focus', poll);
        };
      }, 'dsh-macos-notify: desktop navigation');
      poll();
    }

    /** The notification surface (absent in insecure or legacy contexts). */
    function notificationsApi() {
      return typeof Notification === 'undefined' ? null : Notification;
    }

    /** Ask once, on the first real user gesture (browsers reject programmatic prompts). */
    function ensurePermission() {
      var api = notificationsApi();
      if (api === null || api.permission !== 'default') return;
      var ask = function () {
        window.removeEventListener('pointerdown', ask, true);
        window.removeEventListener('keydown', ask, true);
        try { api.requestPermission().catch(function () {}); } catch (e) { /* 忽略 */ }
      };
      window.addEventListener('pointerdown', ask, true);
      window.addEventListener('keydown', ask, true);
    }

    /** One-line session label for a notification body. */
    function labelOf(row, id) {
      var text = row && (row.displayTitle || row.title);
      var trimmed = typeof text === 'string' ? text.trim() : '';
      return trimmed !== '' ? trimmed : T('会话 ') + String(id || '').slice(0, 8);
    }

    /**
     * Feature 1: `?session=<id>` deep link.
     * @param ctx - client context.
     * @param sessions - the sessions service.
     */
    function applyDeepLink(ctx, sessions) {
      var wanted = null;
      try {
        wanted = new URLSearchParams(window.location.search).get('session');
      } catch (e) {
        return;
      }
      if (!wanted) return;

      var startedAt = Date.now();
      var done = false;
      var off = null;
      var finish = function (selected) {
        if (done) return;
        done = true;
        try { if (typeof off === 'function') off(); } catch (e) { /* 忽略 */ }
        if (selected !== true) return;
        try {
          var url = new URL(window.location.href);
          url.searchParams.delete('session');
          var query = url.searchParams.toString();
          window.history.replaceState(null, '', url.pathname + (query ? '?' + query : '') + url.hash);
        } catch (e) { /* 清 URL 失败不影响跳转 */ }
      };
      // 应用是否已经完成自己的初始导航。
      //
      // 这是本插件最关键的一条时序约束。0.1.7 的 ui-workspace 启动协调器是这么写的：
      //
      //   const reconcile = () => {
      //     if (initial !== "waiting") return;
      //     if (workspace.phase !== "ready" || sessions.phase !== "ready") return;
      //     if (this.mainReference !== void 0) { initial = "done"; return; }   // ★
      //     initial = "connecting";
      //     this.restoreSelection(workspace, sessions).then(...);              // ← 连接工作区
      //   };
      //
      // ★ 只要 mainReference 非空就直接收工，而 restoreSelection 才是**连接工作区**的那步。
      // 插件若抢在它前面调用 openSession，就会把 mainReference 提前设上，于是协调器
      // 判定"已经有主视图了"，永远跳过工作区连接。实测症状：
      //   · 左栏只有工作区、列不出会话
      //   · 左栏单击切换会话无效（双击却能打开重命名，弹出类菜单也正常）
      //   · 顶部"新会话"能建出来但页面不跳转
      // `mainReference` 是公开类字段，可以直接读——用应用自己的闸门当就绪信号，
      // 这样激活时机就与侧栏点击（总发生在启动完成之后）完全一致。
      var activating = false;
      var attempt = function () {
        if (done || activating) return;
        var snapshot = null;
        try { snapshot = sessions.list.getSnapshot(); } catch (e) { return; }
        var ids = (snapshot && snapshot.ids) || [];
        if (ids.indexOf(wanted) === -1) return;
        var workspace = workspaceServiceOf(ctx);
        // 应用还没完成自己的初始导航之前，绝不碰 openSession（见 appNavigated 的说明：
        // 抢跑会让协调器永远跳过工作区连接）。超时后不再等待，照常尝试。
        if (!appNavigated(workspace) && Date.now() - startedAt < SETTLE_WAIT_MS) return;
        // 已经就在目标会话上（例如本次打开前它本来就是当前会话）：直接收工。
        if (isCurrent(workspace, wanted)) { finish(true); return; }
        // 切换可能是异步的（跨工作区时要先连接目标工作区），用 activating 防止重入。
        activating = true;
        activateSession(ctx, wanted).then(function (ok) {
          activating = false;
          if (done) return;
          // 只有**复核确认**切过去了才清 URL。早期版本无条件 finish(true)：
          // 激活失败时 URL 照样被清掉，页面就停在"上次浏览的会话"上——表现为
          // "跳到了错的会话"，而地址栏干干净净，看着像成功，极难排查。
          if (ok === true) finish(true);
        }, function () { activating = false; });
      };
      try { off = sessions.list.subscribe(attempt); } catch (e) { /* 下面仍试一次 */ }
      // 成功之前持续重试：uiWorkspace 可能比插件晚就绪，而列表订阅只在会话集合
      // 变化时才回调，未必会再叫醒我们。**成功即停手**——激活是一次性动作，
      // 不是需要反复声明的状态（曾经成功后再"坚持"5 次，就是和用户点击抢状态）。
      var tries = 0;
      var retry = null;
      var start = function () {
        attempt();
        if (done) return;
        retry = window.setInterval(function () {
          if (done || tries >= 30) { window.clearInterval(retry); return; }
          tries += 1;
          attempt();
        }, 400);
      };
      // 首次尝试前留一拍：侧栏点击总在启动完成之后，插件却在启动中途就跑起来了。
      window.setTimeout(start, DEEPLINK_GRACE_MS);
      if (typeof ctx.effect === 'function') {
        try {
          ctx.effect(function () { return function () { finish(false); }; }, 'dsh-macos-notify: deeplink');
        } catch (e) { /* 忽略 */ }
      }
      window.setTimeout(function () {
        if (!done) {
          try {
            console.warn('[dsh-macos-notify] 深链未能切到会话 ' + wanted + '：会话不在列表里，或 uiWorkspace 不可用。URL 参数已保留，可刷新重试。');
          } catch (e) { /* 忽略 */ }
        }
        finish(false);
      }, DEEPLINK_GIVE_UP_MS);
    }

    /**
     * Feature 2: clickable completion / waiting notifications while hidden.
     * @param ctx - client context.
     * @param sessions - the sessions service.
     */
    /**
     * 浏览器通知开关，默认关闭。
     *
     * 关闭理由（2026-09-19 实测确认）：页面内通知随页面生命周期消失，直接违反
     * DSH-Jump 的 P0 需求「关掉 Harness 标签页之后通知能力不能一起消失」；而且
     * 它与 DSH-Jump 扩展 / 宿主 applet 两条通道重复。实测事故：GUI 开在 Safari 时
     * 弹出的网页通知被点击后只激活了 Safari，把"跳到 Chrome 里的会话"变成了
     * "跳到 Safari"，用户看到的是错误的浏览器。
     *
     * 临时打开（用于对比诊断）：控制台执行
     *   localStorage.setItem('dsh-macos-notify:notifications', 'on')
     * 然后刷新页面；设成 'off' 可显式关闭。
     */
    var BROWSER_NOTIFICATIONS_DEFAULT = false;

    function browserNotificationsEnabled() {
      try {
        var v = window.localStorage.getItem('dsh-macos-notify:notifications');
        if (v === 'on') return true;
        if (v === 'off') return false;
      } catch (e) { /* 读不到就用默认值 */ }
      return BROWSER_NOTIFICATIONS_DEFAULT;
    }

    function applyNotifications(ctx, sessions) {
      if (!browserNotificationsEnabled()) return;
      var api = notificationsApi();
      if (api === null) return;
      ensurePermission();

      var previous = new Map(); // id -> { running, pending }
      /**
       * Whether the user is away from the DSH page. `document.hidden` alone is
       * not enough: switching to another app (Cmd+Tab) usually leaves the
       * browser window visible, so the tab still reports "visible" — the window
       * simply loses focus. Treat both as away.
       */
      var away = function () {
        try {
          if (document.hidden) return true;
          if (typeof document.hasFocus === 'function') return !document.hasFocus();
        } catch (e) { /* 读不到就当作在前台 */ }
        return false;
      };

      var show = function (title, body, sessionId) {
        if (api.permission !== 'granted') return;
        // 按用户要求：取消"窗口有焦点就不弹"的抑制——每轮任务完成都弹通知。
        try {
          console.info(
            '[dsh-macos-notify] ' + title, sessionId,
            'hidden=' + document.hidden,
            'focus=' + (typeof document.hasFocus === 'function' ? document.hasFocus() : 'n/a'),
            'perm=' + api.permission,
          );
        } catch (e) { /* 忽略 */ }
        try {
          var notification = new api(title, { body: body, tag: 'dsh-macos-notify-' + sessionId });
          notification.onclick = function () {
            try { window.focus(); } catch (e) { /* 忽略 */ }
            // 这是真实用户点击，时机天然正确；仍要吞掉 promise 以免未处理拒绝。
            activateSession(ctx, sessionId).catch(function () { /* 忽略 */ });
            try { notification.close(); } catch (e) { /* 忽略 */ }
          };
        } catch (e) { /* 通知失败不影响页面 */ }
      };

      /**
       * Whether a row currently waits for user input. This DSH version keeps the
       * pending-interaction source inside the UI slots (not reachable from a
       * standalone client plugin), so this check is defensive: it lights up by
       * itself if a future version exposes one of these row fields.
       */
      var pendingOf = function (row) {
        return row.pendingInteraction !== undefined || row.pending === true || row.awaiting === true;
      };

      var seed = function () {
        previous.clear();
        var snapshot = null;
        try { snapshot = sessions.list.getSnapshot(); } catch (e) { return; }
        var ids = (snapshot && snapshot.ids) || [];
        for (var i = 0; i < ids.length; i++) {
          var row = snapshot.byId[ids[i]];
          if (!row) continue;
          previous.set(ids[i], { running: !!row.running, pending: pendingOf(row) });
        }
      };

      var run = function () {
        var snapshot = null;
        try { snapshot = sessions.list.getSnapshot(); } catch (e) { return; }
        var ids = (snapshot && snapshot.ids) || [];
        var live = {};
        for (var i = 0; i < ids.length; i++) {
          var id = ids[i];
          var row = snapshot.byId[id];
          if (!row) continue;
          live[id] = true;
          if (String(row.origin || '') === 'subagent') continue; // 子代理会话不打扰
          var pending = pendingOf(row);
          var state = previous.get(id);
          if (state === undefined) {
            previous.set(id, { running: !!row.running, pending: pending });
            continue;
          }
          var awayNow = away();
          if (state.pending === false && pending === true) {
            try { console.info('[dsh-macos-notify] edge 待操作', id, 'away=' + awayNow, 'hidden=' + document.hidden, 'focus=' + (typeof document.hasFocus === 'function' ? document.hasFocus() : 'n/a')) } catch (e) { /* 忽略 */ }
            show(T('需要你的操作'), labelOf(row, id), id);
          } else if (state.running === true && row.running === false && !pending) {
            try { console.info('[dsh-macos-notify] edge 完成', id, 'away=' + awayNow, 'hidden=' + document.hidden, 'focus=' + (typeof document.hasFocus === 'function' ? document.hasFocus() : 'n/a')) } catch (e) { /* 忽略 */ }
            show(T('任务完成'), labelOf(row, id), id);
          }
          state.running = !!row.running;
          state.pending = pending;
        }
        previous.forEach(function (value, key) { if (!live[key]) previous.delete(key); });
      };

      seed();
      var off = null;
      var offReset = null;
      try { off = sessions.list.subscribe(run); } catch (e) { /* 忽略 */ }
      try { offReset = ctx.on('connection/reset', seed); } catch (e) { /* 忽略 */ }
      if (typeof ctx.effect === 'function') {
        try {
          ctx.effect(function () {
            return function () {
              try { if (typeof off === 'function') off(); } catch (e) { /* 忽略 */ }
              try { if (typeof offReset === 'function') offReset(); } catch (e) { /* 忽略 */ }
            };
          }, 'dsh-macos-notify: notifications');
        } catch (e) { /* 忽略 */ }
      }
    }

    /**
     * Compose both features.
     * @param ctx - client root context.
     */
    function applySettings(ctx, sessions) {
      var slots = ctx.get('slots'), connection = ctx.get('connection'), React;
      try { React = require('react'); } catch (_) { return; }
      if (!slots || !connection || !React || typeof React.useState !== 'function') return;
      var rpc = function (endpoint, payload) {
        return connection.rpc.call('/api', 'dsh-macos-notify/' + endpoint, payload || {}).then(function (result) {
          if (!result || result.ok !== true) throw new Error(T('DSH 未确认请求'));
          return result.value;
        });
      };
      var clientId = 'view-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2), presenceSequence = 0;
      var presence = function () {
        rpc('foreground', { clientId: clientId, seq: ++presenceSequence, sessionId: currentSessionIdOf(ctx, sessions), visible: !document.hidden && document.hasFocus() }).catch(function () {});
      };
      var timer = window.setInterval(presence, 2000);
      window.addEventListener('focus', presence); window.addEventListener('blur', presence);
      document.addEventListener('visibilitychange', presence);
      ctx.effect(function () { return function () {
        window.clearInterval(timer); window.removeEventListener('focus', presence); window.removeEventListener('blur', presence);
        rpc('foreground', { clientId: clientId, seq: ++presenceSequence, sessionId: null, visible: false }).catch(function () {}); document.removeEventListener('visibilitychange', presence);
      }; });
      presence();
      var h = React.createElement;
      function Settings() {
        var languageState=React.useState(uiLocale),setLanguage=languageState[1];
        React.useEffect(function () {
          var locale;try {locale=ctx.get('locale');}catch (_) {return;}
          if (!locale || !locale.subscribe) return;
          return locale.subscribe(function () {setLanguage(locale.getSnapshot().active);});
        },[]);

        var pair = React.useState(null), value = pair[0], setValue = pair[1];
        var state = React.useState(null), status = state[0], setStatus = state[1];
        var info = React.useState(''), message = info[0], setMessage = info[1];
        var saving = React.useState(false), busy = saving[0], setBusy = saving[1];
        React.useEffect(function () {
          var disposed = false;
          rpc('settings').then(function (v) { if (!disposed) setValue(v); }).catch(function () { if (!disposed) setMessage('无法连接 DSH，请重连后重试。'); });
          var refresh = function () { rpc('status').then(function (v) { if (!disposed) setStatus(v); }).catch(function () { if (!disposed) setStatus(null); }); };
          refresh(); var poll = window.setInterval(refresh, 2000);
          return function () { disposed = true; window.clearInterval(poll); };
        }, []);
        var row = function (key, label) {
          return h('label', { key: key, style: { display: 'flex', gap: 10, padding: '8px 0', alignItems: 'center' } },
            h('input', { type: 'checkbox', checked: Boolean(value && value[key]), disabled: busy || !value,
              onChange: function (event) {
                var patch = {}; patch[key] = event.target.checked; setBusy(true);
                rpc('save', patch).then(function (v) { setValue(v); setMessage('设置已保存'); }).catch(function () { setMessage('保存未成功，请重试。'); }).finally(function () { setBusy(false); });
              } }), label);
        };
        var helper = status && status.helper;
        var testState = status && status.test;
        var testLabel = testState && ({ none: T('尚未进行安全测试'), 'queue-failed': T('测试未排队，请检查助手'), 'waiting-for-helper': T('已排队，等待助手'), 'waiting-for-click': T('已交给 macOS，等待点击通知'), opening: T('已点击，正在确认目标会话'), confirmed: T('已确认打开目标会话'), 'timed-out': T('未确认跳转，请检查 DSH 后重试'), 'system-rejected': T('macOS 未接受通知，请检查权限'), expired: T('助手未确认收到测试，请检查后重试') }[testState.state]);
        var permission = helper && ({ authorized: T('已允许'), denied: T('未允许，请在系统设置中允许 DSH Notify'), notDetermined: T('等待授权'), provisional: T('临时允许'), unknown: T('未知') }[helper.permission]);
        return h('section', { style: { padding: 24, maxWidth: 760, color: 'inherit' } },
          h('h2', null, 'DSH Notify'),
          h('p', null, T('macOS 原生通知、审批和完整问答')),
          h('fieldset', { style: { border: '1px solid #8885', borderRadius: 8, padding: 16 } }, h('legend', null, T('提醒类型')),
            row('completed', T('任务完成')), row('error', T('任务出错')), row('approval', T('需要审批')), row('questions', T('需要回答问题'))),
          h('fieldset', { style: { border: '1px solid #8885', borderRadius: 8, padding: 16, marginTop: 16 } }, h('legend', null, T('提醒方式')),
            row('sound', T('播放系统提示音')), row('includeSubagents', T('单独提醒子智能体结果')), row('waitForChildren', T('等待子智能体结束后汇总主任务完成')),
            row('quietCurrentSession', T('正在前台查看对应会话时静默提醒'))),
          h('p', null, T('静默仅影响通知；已经打开的审批或问答面板始终保留。')),
          h('fieldset', { style: { border: '1px solid #8885', borderRadius: 8, padding: 16, marginTop: 16 } }, h('legend', null, T('菜单栏')),
            row('menuBarEnabled', T('启用菜单栏会话面板'))),
          h('h3', null, T('运行状态')),
          h('p', null, status ? T('插件版本 ') + status.version + T(' · DSH 已连接') : T('DSH 状态暂不可用')),
          h('p', null, helper && helper.running ? T('助手运行中 · 版本 ') + helper.version + T(' · 通知权限：') + permission : T('助手未运行或尚未安装')),
          status && status.versionMismatch ? h('p', { role: 'status' }, T('插件与助手版本不同，请更新后正常重启 DSH。')) : null,
          h('p', null, T('安全测试：') + (testLabel || T('状态暂不可用'))),
          status ? h('p', null, T('已排队 ') + status.notifications.posted + T(' · 已静默 ') + status.notifications.suppressed + T(' · 等待子智能体 ') + status.notifications.waitingForChildren) : null,
          h('button', { type: 'button', disabled: busy || !helper || !helper.running,
            onClick: function () { setBusy(true); rpc('test', { sessionId: currentSessionIdOf(ctx, sessions) }).then(function () { setMessage('安全测试通知已排队，请实际点击通知核对会话。'); }).catch(function () { setMessage('测试未成功，请检查连接。'); }).finally(function () { setBusy(false); }); }
          }, T('发送安全测试通知')),
          h('p', { role: 'status', 'aria-live': 'polite' }, T(message)),
          h('a', { href: 'https://github.com/realDGD/dsh-macos-notify#installation', target: '_blank', rel: 'noreferrer' }, T('安装、升级与故障排查')));
      }
      slots.inject('settings.section', function () { return slots.register({ name: 'settings.section', id: 'dsh-macos-notify', order: 25, label: 'DSH Notify' }, Settings); });
    }

    function apply(ctx) {
      applyUILanguage(ctx);
      try {
        var sessions = typeof ctx.get === 'function' ? ctx.get('sessions') : null;
        if (!sessions || !sessions.list) return;
        applyDeepLink(ctx, sessions);
        applyDesktopJump(ctx, sessions);
        applyNotifications(ctx, sessions);
        applySettings(ctx, sessions);
        // 诊断钩子：浏览器控制台执行 __dshNotifyWebTest() 立即弹一条可点击通知，
        // 返回发送结果（含当前权限），用于把"权限/浏览器管道"与"事件判定"分开排查。
        try {
          window.__dshNotifyWebTest = function (id) {
            try {
              // 目标：显式 id > 列表里第一个"非当前"会话（这样点击后界面必然可见地切换）> 当前会话
              var snapshot = sessions.list.getSnapshot();
              var ids = (snapshot && snapshot.ids) || [];
              var target = typeof id === 'string' && id !== '' ? id : null;
              if (target === null) {
                var current = currentSessionIdOf(ctx, sessions);
                for (var i = 0; i < ids.length; i++) { if (ids[i] !== current) { target = ids[i]; break; } }
              }
              if (target === null) target = currentSessionIdOf(ctx, sessions);
              var notice = new Notification(T('DSH 测试通知'), {
                body: T('点击应切到会话 ') + String(target).slice(0, 12) + '…',
                tag: 'dsh-macos-notify-test',
              });
              notice.onclick = function () {
                try { console.info('[dsh-macos-notify] notification clicked ->', target); } catch (e) { /* 忽略 */ }
                try { window.focus(); } catch (e) { /* 忽略 */ }
                activateSession(ctx, target).then(function (ok) {
                  try { console.info('[dsh-macos-notify] activateSession confirmed =', ok, '->', target); } catch (e) { /* 忽略 */ }
                }, function (reason) {
                  try { console.warn('[dsh-macos-notify] activateSession failed', reason); } catch (e) { /* 忽略 */ }
                });
                try { notice.close(); } catch (e) { /* 忽略 */ }
              };
              return 'sent -> click should jump to ' + target + ' (permission=' + Notification.permission + ')';
            } catch (e) {
              return 'failed: ' + (e && e.message ? e.message : String(e)) + ' (permission=' + (typeof Notification === 'undefined' ? 'unavailable' : Notification.permission) + ')';
            }
          };
        } catch (e) { /* 忽略 */ }
        // 诊断钩子：控制台执行 __dshNotifyJumpTest() 切到"另一个会话"（可见验证切换是否生效）。
        try {
          window.__dshNotifyJumpTest = function (id) {
            try {
              var snapshot = sessions.list.getSnapshot();
              var ids = (snapshot && snapshot.ids) || [];
              var target = typeof id === 'string' && id !== '' ? id : null;
              var current = currentSessionIdOf(ctx, sessions);
              if (target === null) {
                for (var i = 0; i < ids.length; i++) { if (ids[i] !== current) { target = ids[i]; break; } }
              }
              if (target === null) return 'no other session (count=' + ids.length + ')';
              activateSession(ctx, target).then(function (ok) {
                try { console.info('[dsh-macos-notify] jump test confirmed =', ok, '->', target); } catch (e) { /* 忽略 */ }
              }, function (reason) {
                try { console.warn('[dsh-macos-notify] jump test failed', reason); } catch (e) { /* 忽略 */ }
              });
              return 'jumping -> ' + target + ' (async; see console for confirmation)';
            } catch (e) {
              return 'error: ' + (e && e.message ? e.message : String(e));
            }
          };
        } catch (e) { /* 忽略 */ }
      } catch (e) {
        /* 任何异常都不得影响页面 */
      }
    }

    exports.apply = apply;
    exports.inject = inject;
    return module.exports;
  },
});
