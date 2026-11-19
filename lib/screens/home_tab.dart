<?php
require_once '../config.php';
require_admin();
$active = 'home_notice';
$page_title = "Home Notice & Good News";
$asset_prefix = '../';
$body_class = 'admin-theme';
$msg = '';
$error = '';

function hn_save_setting($pdo, $key, $val) {
    $pdo->prepare("INSERT INTO settings (setting_key, setting_value) VALUES (?, ?) ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value)")->execute([$key, $val]);
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    csrf_verify();
    $form = $_POST['form'] ?? '';

    if ($form === 'save_notice') {
        $text = trim(preg_replace('/\s+/', ' ', (string)($_POST['notice'] ?? '')));
        if ($text === '') {
            $error = 'Type the notice first, or use Delete to remove it.';
        } else {
            hn_save_setting($pdo, 'home_notice_text', mb_substr($text, 0, 500));
            if (function_exists('audit_log')) {
                audit_log('home_notice_saved', mb_substr($text, 0, 80));
            }
            $msg = 'Notice is live on the app and website home.';
        }
    } elseif ($form === 'delete_notice') {
        hn_save_setting($pdo, 'home_notice_text', '');
        if (function_exists('audit_log')) {
            audit_log('home_notice_deleted', '');
        }
        $msg = 'Notice deleted.';
    } elseif ($form === 'save_good_news') {
        $gnText = trim(preg_replace('/\s+/', ' ', (string)($_POST['good_news'] ?? '')));
        if ($gnText === '') {
            $error = 'Type the Good News first, or use Delete to remove it.';
        } else {
            $cleanGn = mb_substr($gnText, 0, 500);
            hn_save_setting($pdo, 'good_news_text', $cleanGn);
            hn_save_setting($pdo, 'good_news_title', '');
            if (function_exists('audit_log')) {
                audit_log('good_news_saved', mb_substr($cleanGn, 0, 80));
            }
            $msg = 'Good News is live on the app and website home.';
        }
    } elseif ($form === 'delete_good_news') {
        hn_save_setting($pdo, 'good_news_text', '');
        hn_save_setting($pdo, 'good_news_title', '');
        if (function_exists('audit_log')) {
            audit_log('good_news_deleted', '');
        }
        $msg = 'Good News deleted.';
    }
}

$curNotice = trim((string)$pdo->query("SELECT setting_value FROM settings WHERE setting_key = 'home_notice_text'")->fetchColumn());
$curGn = trim((string)$pdo->query("SELECT setting_value FROM settings WHERE setting_key = 'good_news_text'")->fetchColumn());
if ($curGn === '') {
    $legacyTitle = trim((string)$pdo->query("SELECT setting_value FROM settings WHERE setting_key = 'good_news_title'")->fetchColumn());
    $curGn = $legacyTitle;
}

include '../includes/header.php';
?>
<div class="app">
    <?php include 'includes-sidebar.php'; ?>
    <div class="main">
        <div class="topbar"><h2>Home Notice &amp; Good News</h2></div>
        <?php if ($msg): ?><div class="alert alert-ok"><?php echo htmlspecialchars($msg); ?></div><?php endif; ?>
        <?php if ($error): ?><div class="alert alert-error"><?php echo htmlspecialchars($error); ?></div><?php endif; ?>

        <div class="card" style="max-width:680px; margin-bottom:20px;">
            <h3 style="margin-bottom:6px;">Home Notice</h3>
            <p style="font-size:13px; color:var(--text-dim); margin-bottom:12px;">A one-line red notice that scrolls slowly across the top of every customer's home screen (app and website), then starts again from the beginning. It stays until you delete it. Edit it any time.</p>
            <?php if ($curNotice !== ''): ?>
                <div style="background:#FBE7E5; color:#B3261E; border-radius:10px; padding:10px 14px; margin-bottom:14px; font-weight:600;">&#128226; <?php echo htmlspecialchars($curNotice); ?></div>
            <?php endif; ?>
            <form method="POST">
                <?php echo csrf_field(); ?>
                <input type="hidden" name="form" value="save_notice">
                <div class="field">
                    <label>Notice</label>
                    <textarea name="notice" rows="2" maxlength="500" placeholder="Type one-line notice..."><?php echo htmlspecialchars($curNotice); ?></textarea>
                </div>
                <button class="btn btn-primary"><?php echo $curNotice !== '' ? 'Update notice' : 'Post notice'; ?></button>
            </form>
            <?php if ($curNotice !== ''): ?>
                <form method="POST" style="margin-top:12px;" onsubmit="return confirm('Delete the notice?');">
                    <?php echo csrf_field(); ?>
                    <input type="hidden" name="form" value="delete_notice">
                    <button class="btn btn-outline" style="color:var(--red); border-color:var(--red);">Delete notice</button>
                </form>
            <?php endif; ?>
        </div>

        <div class="card" style="max-width:680px;">
            <h3 style="margin-bottom:6px;">Good News</h3>
            <p style="font-size:13px; color:var(--text-dim); margin-bottom:12px;">A one-line Good News message (no title needed) that scrolls slowly across every customer's home screen (app and website), then starts again from the beginning.</p>
            <?php if ($curGn !== ''): ?>
                <div style="background:#E8F6EE; color:#146C43; border-radius:10px; padding:10px 14px; margin-bottom:14px; font-weight:600;">&#127881; <?php echo htmlspecialchars($curGn); ?></div>
            <?php endif; ?>
            <form method="POST">
                <?php echo csrf_field(); ?>
                <input type="hidden" name="form" value="save_good_news">
                <div class="field">
                    <label>Good News</label>
                    <textarea name="good_news" rows="2" maxlength="500" placeholder="Type one-line good news..."><?php echo htmlspecialchars($curGn); ?></textarea>
                </div>
                <button class="btn btn-primary"><?php echo $curGn !== '' ? 'Update Good News' : 'Post Good News'; ?></button>
            </form>
            <?php if ($curGn !== ''): ?>
                <form method="POST" style="margin-top:12px;" onsubmit="return confirm('Delete Good News?');">
                    <?php echo csrf_field(); ?>
                    <input type="hidden" name="form" value="delete_good_news">
                    <button class="btn btn-outline" style="color:var(--red); border-color:var(--red);">Delete Good News</button>
                </form>
            <?php endif; ?>
        </div>
    </div>
</div>
<?php include '../includes/footer.php'; ?>
