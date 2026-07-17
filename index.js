const STORE = {
  get(k, fallback=null){ try { const v = localStorage.getItem(k); return v ? JSON.parse(v) : fallback; } catch(e){ return fallback; } },
  set(k, v){ localStorage.setItem(k, JSON.stringify(v)); },
  remove(k){ localStorage.removeItem(k); }
};

const DEFAULT_CATS = ['أفلام','مسلسلات','يوتيوب','تعليم','طبخ','مشتريات','أفكار','أخرى'];
const CATEGORY_RULES = [
  { cat:'طبخ', words:['طبخ','مطبخ','وصفة','وصفات','مقادير','مكونات','بيتزا','عجينة','صلصة','جبن','خبز','كيك','حلويات','أكل','اكل','طعام','مندي','كبسة','رز','دجاج','لحم','سلطة','مشروب','قهوة','recipe','recipes','cooking','cook','food','pizza','ingredients','kitchen','baking'] },
  { cat:'تعليم', words:['تعليم','شرح','درس','دروس','تعلم','محاضرة','كورس','دورة','اختبار','مدرسة','جامعة','رياضيات','كيمياء','فيزياء','برمجة','تدريب','tutorial','course','lesson','learn','education','explained','study','training'] },
  { cat:'مشتريات', words:['شراء','تسوق','منتج','منتجات','سعر','خصم','كود خصم','عرض','متجر','سلة','أمازون','امازون','نون','طلبات','شي ان','شيء ان','buy','shop','shopping','store','price','discount','coupon','deal','product','amazon','noon'] },
  { cat:'أفلام', words:['فيلم','افلام','أفلام','سينما','تريلر','trailer','movie','movies','film','cinema'] },
  { cat:'مسلسلات', words:['مسلسل','مسلسلات','حلقة','موسم','episode','episodes','series','season'] },
  { cat:'أفكار', words:['فكرة','افكار','أفكار','إلهام','الهام','تصميم','ديكور','مشروع','ابتكار','idea','ideas','inspiration','design','decor','project'] }
];
const LS_LINKS = 'lv_links_v2';
const LS_CATS = 'lv_cats_v2';
const LS_SETTINGS = 'lv_settings_v2';
const LS_UI = 'lv_ui_v1';
const LS_PENDING_OTP = 'lv_pending_otp_email_v1';
const LS_LANG = 'lv_language_v1';
const LS_PROTECTED_CATS = 'lv_protected_cats_v1';
const LS_ACTIVE_CLOUD_USER = 'lv_active_cloud_user_v1';
const OTHER_CAT = 'أخرى';
const FAVORITES_FILTER = 'favorites';
const AUTH_REDIRECT_URL = 'linkvaultq8://auth-callback';
const PLAN_LIMITS = { freeLinks:10, freeCustomCategories:3 };
const APP_EDITION = (window.LINKVAULT_CONFIG && window.LINKVAULT_CONFIG.APP_EDITION) || 'full';
const REVENUECAT_DEFAULT_PRICES = { monthly:'$1.99', annual:'$14.99', lifetime:'$29.99' };

let legacyLinks = STORE.get('lv_links', []);
let legacyCats = STORE.get('lv_cats', null);
let links = normalizeLinks(STORE.get(LS_LINKS, legacyLinks || []));
let cats = normalizeCategories(STORE.get(LS_CATS, legacyCats || DEFAULT_CATS));
let protectedCats = new Set((STORE.get(LS_PROTECTED_CATS, DEFAULT_CATS.filter(c=>c!==OTHER_CAT)) || []).map(x=>String(x||'').trim()).filter(Boolean));
let editId = null;
let currentCat = 'all';
let sbClient = null;
let cloudUser = null;
let syncing = false;
let authSyncPromise = null;
let toastTimer = null;
let uiPrefs = STORE.get(LS_UI, { theme:'dark', viewMode:'cards' }) || { theme:'dark', viewMode:'cards' };
let currentTheme = ['dark','light','beige'].includes(uiPrefs.theme) ? uiPrefs.theme : 'dark';
let viewMode = ['cards','compact','grid'].includes(uiPrefs.viewMode) ? uiPrefs.viewMode : 'cards';
let selectionMode = false;
let selectedIds = new Set();
let pendingRestoreData = null;
let pendingAuthCallbackUrl = '';
let pendingOtpEmail = STORE.get(LS_PENDING_OTP, '') || '';
let otpCooldownTimer = null;
let isPro = APP_EDITION === 'full';
let rcReady = false;
let rcCustomerInfo = null;
let rcOffering = null;
let rcPackages = { monthly:null, annual:null, lifetime:null };

const I18N_EN = {"مكتبة روابطك الذكية":"Your smart link library","الإعدادات":"Settings","حالة المزامنة":"Sync status","إضافة رابط":"Add link","محلي":"Local","ابحث في الروابط والعناوين والملاحظات...":"Search links, titles, and notes...","مسح البحث":"Clear search","طريقة العرض":"View style","بطاقات":"Cards","مختصر":"Compact","شبكة":"Grid","☑ تحديد":"☑ Select","✕ إنهاء":"✕ Done","تحديد":"Select","تحديد الظاهر":"Select visible","إلغاء التحديد":"Clear selection","حذف المحدد":"Delete selected","مسح الجميع":"Delete all","إضافة رابط جديد":"Add new link","➕ إضافة رابط جديد":"➕ Add new link","✏️ تعديل الرابط":"✏️ Edit link","الرابط":"Link","الصق الرابط هنا...":"Paste the link here...","✨ جلب العنوان والصورة":"✨ Fetch title and image","📝 العنوان":"📝 Title","العنوان":"Title","اكتب عنواناً للرابط...":"Enter a title for the link...","🗂️ التصنيف":"🗂️ Type","التصنيف":"Type","🏷️ المنصة":"🏷️ Platform","المنصة":"Platform","تلقائي":"Automatic","🖼️ صورة مصغرة (اختياري)":"🖼️ Thumbnail (optional)","🎬 رابط التريلر (اختياري)":"🎬 Trailer link (optional)","إذا ما عندك رابط التريلر، استخدم زر البحث وسيتم فتح نتائج يوتيوب تلقائيًا.":"If you do not have a trailer link, use search to open YouTube results automatically.","🎬 بحث عن تريلر رسمي في يوتيوب":"🎬 Search YouTube for an official trailer","📌 ملاحظات":"📌 Notes","ملاحظات":"Notes","أي ملاحظات تريد إضافتها... مثل: شفته، مهم، للرجوع لاحقًا...":"Add any notes, such as watched, important, or save for later...","💾 حفظ":"💾 Save","حفظ":"Save","إلغاء":"Cancel","إغلاق":"Close","⚙️ الإعدادات والمزامنة":"⚙️ Settings and sync","الوضع الحالي: حفظ محلي على الجهاز.":"Current mode: saved locally on this device.","🔐 الحساب والمزامنة":"🔐 Account and sync","📧 البريد الإلكتروني":"📧 Email address","إرسال رمز التحقق":"Send verification code","🔢 رمز التحقق":"🔢 Verification code","تأكيد":"Confirm","إعادة إرسال الرمز":"Resend code","أو":"or","رمز البريد ينشئ الحساب تلقائيًا للمستخدم الجديد. لا توجد كلمة مرور.":"The email code automatically creates an account for a new user. No password is required.","مزامنة الآن":"Sync now","تسجيل خروج":"Sign out","🎨 ثيم التطبيق":"🎨 App theme","داكن":"Dark","أبيض":"Light","بيج":"Beige","🌐 لغة التطبيق":"🌐 App language","لغة التطبيق":"App language","لغة الجهاز":"Device language","العربية":"Arabic","إذا كانت لغة الجهاز العربية سيعمل التطبيق بالعربية، وأي لغة أخرى تستخدم الإنجليزية تلقائيًا.":"Arabic is used only when the device language is Arabic; every other device language defaults to English.","🗄️ النسخ الاحتياطي والاستعادة":"🗄️ Backup and restore","النسخة تشمل الروابط والتصنيفات والملاحظات والصور والتريلرات، ولا تشمل كلمة المرور أو بيانات جلسة الدخول.":"The backup includes links, types, notes, images, and trailers. It does not include passwords or sign-in session data.","⬆️ باك أب":"⬆️ Back up","⬇️ ريستور":"⬇️ Restore","ℹ️ عن التطبيق":"ℹ️ About the app","التطبيق من عمل M. ALQattan":"Created by M. ALQattan","📬 تواصل معنا":"📬 Contact us","تابعنا":"Follow us","🔧 تشخيص المشاركة (Share Extension)":"🔧 Share Extension diagnostics","اضغط هذا الزر بعد ما تشارك رابط من تطبيق ثاني (وقبل لا تسكر LinkVault)، عشان تشوف بالضبط وين المشكلة لو الرابط ما يوصل.":"Use this after sharing a link from another app to diagnose why it did not reach LinkVault.","🔍 افحص الروابط المشتركة الآن":"🔍 Check shared links now","🗂️ إدارة الأنواع":"🗂️ Manage types","إدارة الأنواع":"Manage types","⚙️ إدارة":"⚙️ Manage","إدارة":"Manage","أضف نوعًا جديدًا أو عدّل الاسم أو غيّر الترتيب أو احذف أي نوع. خيار «أخرى» يبقى دائمًا في النهاية ويستقبل روابط النوع المحذوف.":"Add a new type, rename it, reorder it, or delete any type. “Other” always stays last and receives links from a deleted type.","اسم التصنيف: أفلام، طبخ، تعليم...":"Type name: Movies, Cooking, Education...","إضافة":"Add","🗄️ استعادة النسخة الاحتياطية":"🗄️ Restore backup","دمج مع البيانات الحالية":"Merge with current data","استبدال البيانات الحالية":"Replace current data","أفلام":"Movies","مسلسلات":"TV Shows","يوتيوب":"YouTube","تعليم":"Education","طبخ":"Cooking","مشتريات":"Shopping","أفكار":"Ideas","أخرى":"Other","كل الأنواع":"All types","⭐ المفضلة":"⭐ Favorites","المفضلة":"Favorites","مفضلة":"Favorite","رابط":"Link","تصنيف":"Type","تريلر":"Trailer","لا نتائج":"No results","لا يوجد روابط بعد":"No links yet","جرب كلمة بحث مختلفة":"Try a different search term","اضغط + لإضافة رابط جديد":"Tap + to add a new link","أو شاركه من أي تطبيق آخر":"or share it from any other app","تحديد الرابط":"Select link","مشاركة":"Share","تعديل":"Edit","حذف":"Delete","صورة الرابط":"Link image","شاهد":"Watch","تعديل الاسم":"Rename","تحريك للأعلى":"Move up","تحريك للأسفل":"Move down","حذف النوع":"Delete type","(آخر القائمة)":"(last in list)","(أساسي)":"(built-in)","⚠️ الرابط مطلوب":"⚠️ A link is required","⚠️ الرابط لازم يبدأ بـ http أو https":"⚠️ The link must start with http or https","✅ تم التعديل":"✅ Updated","ℹ️ الرابط كان محفوظ، وتم تحديثه":"ℹ️ This link was already saved and has been updated","✅ تم الحفظ":"✅ Saved","حذف هذا الرابط؟":"Delete this link?","تم الحذف":"Deleted","اختر رابطًا واحدًا على الأقل":"Select at least one link","لا توجد روابط للحذف":"There are no links to delete","تم مسح جميع الروابط":"All links were deleted","نسخة LinkVault الاحتياطية":"LinkVault backup","✅ تم تجهيز النسخة الاحتياطية":"✅ Backup is ready","✅ تم حفظ النسخة الاحتياطية":"✅ Backup saved","⚠️ تعذر إنشاء النسخة الاحتياطية":"⚠️ Could not create the backup","ملف غير صالح":"Invalid file","سيتم استبدال جميع الروابط والتصنيفات الحالية. هل أنت متأكد؟":"All current links and types will be replaced. Are you sure?","✅ تمت استعادة النسخة واستبدال البيانات":"✅ Backup restored and current data replaced","✅ تم دمج النسخة الاحتياطية":"✅ Backup merged","✅ تمت مشاركة الرابط":"✅ Link shared","📋 تم نسخ الرابط. الصقه في التطبيق الذي تريد مشاركته.":"📋 Link copied. Paste it into the app where you want to share it.","انسخ هذا الرابط للمشاركة":"Copy this link to share","⚠️ أدخل اسم النوع":"⚠️ Enter a type name","⚠️ هذا الخيار موجود مسبقًا":"⚠️ This option already exists","⚠️ لا يمكن تعديل خيار أخرى":"⚠️ The Other option cannot be renamed","⚠️ اسم أخرى محجوز":"⚠️ The name Other is reserved","⚠️ هذا النوع موجود مسبقًا":"⚠️ This type already exists","⚠️ لا يمكن حذف خيار أخرى لأنه يستقبل روابط الأنواع المحذوفة":"⚠️ The Other type cannot be deleted because it receives links from deleted types","✅ تم حذف النوع ونقل روابطه إلى أخرى":"✅ Type deleted and its links moved to Other","✅ تم حذف النوع":"✅ Type deleted","✅ تم تحديث ترتيب الأنواع":"✅ Type order updated","⚠️ أدخل الرابط أولاً":"⚠️ Enter the link first","جاري الجلب...":"Fetching...","✅ تم جلب العنوان والصورة":"✅ Title and image fetched","ℹ️ لم أجد عنوان واضح، اكتب العنوان يدويًا":"ℹ️ No clear title was found. Enter it manually.","⚠️ تعذر الجلب. لو الرابط من إنستغرام/تيك توك/فيسبوك اكتب العنوان يدويًا.":"⚠️ Could not fetch details. For Instagram, TikTok, or Facebook, enter the title manually.","⚠️ أدخل العنوان أولاً":"⚠️ Enter the title first","جاري البحث...":"Searching...","✅ تم جلب التريلر":"✅ Trailer fetched","🎬 افتح النتيجة المناسبة وانسخ الرابط":"🎬 Open the correct result and copy its link","🎬 افتح الفيديو المناسب وانسخ رابطه هنا":"🎬 Open the correct video and paste its link here","مزامن":"Synced","غير مسجل":"Signed out","استخدم رمز البريد أو Apple أو Google لتفعيل المزامنة.":"Use email verification, Apple, or Google to enable sync.","خطأ":"Error","تعذر الاتصال بخدمة المزامنة.":"Could not connect to the sync service.","تعذر تحميل بيانات المزامنة. حاول مرة أخرى لاحقًا.":"Could not load synced data. Try again later.","⚠️ سجل دخول أولاً":"⚠️ Sign in first","جاري رفع البيانات المحلية...":"Uploading local data...","✅ تمت المزامنة بنجاح":"✅ Sync completed successfully","✅ تمت المزامنة":"✅ Synced","⚠️ خدمة الحساب غير متاحة حاليًا":"⚠️ Account service is currently unavailable","⚠️ أدخل بريدًا إلكترونيًا صحيحًا":"⚠️ Enter a valid email address","جاري إرسال الرمز...":"Sending code...","📧 تم إرسال رمز التحقق":"📧 Verification code sent","تعذر إرسال رمز التحقق":"Could not send the verification code","⚠️ أدخل رمز التحقق المكوّن من 6 أرقام":"⚠️ Enter the 6-digit verification code","جاري التحقق...":"Verifying...","✅ تم التحقق وتسجيل الدخول بنجاح.":"✅ Verified and signed in successfully.","✅ تم تسجيل الدخول":"✅ Signed in","رمز التحقق غير صحيح أو انتهت صلاحيته":"The verification code is incorrect or has expired","لم يتم إنشاء رابط تسجيل الدخول":"The sign-in link could not be created","تم تسجيل الخروج. الروابط المحلية باقية على هذا الجهاز.":"Signed out. Local links remain on this device.","تم تسجيل الخروج":"Signed out","رابط تسجيل الدخول لا يحتوي بيانات جلسة صالحة":"The sign-in link does not contain a valid session","✅ تم تسجيل الدخول بنجاح.":"✅ Signed in successfully.","⚠️ تعذر إكمال تسجيل الدخول":"⚠️ Could not complete sign-in","⚠️ ملف النسخة الاحتياطية غير صالح":"⚠️ The backup file is invalid","رابط محفوظ":"Saved link","✅ الرابط محفوظ مسبقًا وتم تحديث بياناته":"✅ The link was already saved and its details were updated","ℹ️ الرابط محفوظ مسبقًا":"ℹ️ The link is already saved","📲 ثبّت LinkVault كتطبيق":"📲 Install LinkVault as an app","تثبيت":"Install","تطبيق آيفون أصلي (native):":"Native iPhone app:","نعم ✅":"Yes ✅","لا ❌ (يبدو إنك بمتصفح ويب عادي)":"No ❌ (this appears to be a regular web browser)","إضافة PendingShare مسجلة بالتطبيق:":"PendingShare plugin registered:","لا ❌":"No ❌","⚠️ توجد بيانات مشاركة لكن تعذر استيرادها.":"⚠️ Shared data exists but could not be imported.","يعني: الـ plugin شغال، لكن لا توجد روابط محفوظة في App Group حاليًا. جرّب مشاركة رابط جديد ثم افتح التطبيق.":"The plugin is working, but there are no links currently stored in the App Group. Share a new link and reopen the app.","⚠️ صار خطأ فعلي أثناء الفحص:":"⚠️ A diagnostic error occurred:","LinkVault — مكتبة الروابط":"LinkVault — Link library","LinkVault — مكتبة روابطك الذكية":"LinkVault — Your smart link library","▤ بطاقات":"▤ Cards","☷ مختصر":"☷ Compact","▦ شبكة":"▦ Grid","🔗 الرابط":"🔗 Link","قائمة النوع":"Type list","التريلر":"Trailer","اضغط لفتح الرابط":"Tap to open link","السبب: PendingSharePlugin غير مسجل داخل Capacitor bridge. تأكد أن البناء الجديد شغّل scripts/add-ios-share-extension.rb وأن Main.storyboard صار يستخدم LinkVaultBridgeViewController.":"Reason: PendingSharePlugin is not registered in the Capacitor bridge. Make sure the new build ran scripts/add-ios-share-extension.rb and Main.storyboard uses LinkVaultBridgeViewController.","✅ تم استيراد الروابط المنتظرة داخل القائمة الآن.":"✅ Pending links were imported into the list."};
const I18N_PATTERNS = [
  [/^🔒 النسخة المجانية تسمح بـ (\d+) روابط فقط$/, '🔒 The free version allows only $1 links'],
  [/^🔒 النسخة المجانية تسمح بـ (\d+) أنواع إضافية فقط$/, '🔒 The free version allows only $1 additional types'],
  [/^(\d+) محدد$/, '$1 selected'],
  [/^⭐ المفضلة(?:\s+(\d+))?$/, '⭐ Favorites $1'],
  [/^✅ تم حفظ الرابط في (.+)$/, '✅ Link saved in $1'],
  [/^حذف (\d+) رابط محدد؟ لا يمكن التراجع\.$/, 'Delete $1 selected links? This cannot be undone.'],
  [/^تم حذف (\d+) رابط$/, 'Deleted $1 links'],
  [/^مسح جميع الروابط وعددها (\d+)؟\nلا يمكن التراجع عن هذه العملية\.$/, 'Delete all $1 links?\nThis action cannot be undone.'],
  [/^الملف يحتوي على (\d+) رابط و(\d+) تصنيف\. اختر الدمج للاحتفاظ بالبيانات الحالية، أو الاستبدال لمسحها ووضع النسخة مكانها\.$/, 'The file contains $1 links and $2 types. Choose Merge to keep current data, or Replace to overwrite it.'],
  [/^✅ تمت إضافة (.+)$/, '✅ Added $1'],
  [/^اكتب الاسم الجديد للنوع (.+)$/, 'Enter a new name for the type $1'],
  [/^✅ تم تعديل النوع إلى (.+)$/, '✅ Type renamed to $1'],
  [/^النوع (.+) يحتوي على (\d+) رابط\. سيتم نقلها إلى أخرى ثم حذف النوع\. متابعة؟$/, 'Type $1 contains $2 links. They will be moved to Other before the type is deleted. Continue?'],
  [/^حذف النوع (.+)؟$/, 'Delete type $1?'],
  [/^مسجل دخول: (.+)$/, 'Signed in: $1'],
  [/^إعادة الإرسال بعد (\d+)ث$/, 'Resend in $1s'],
  [/^📧 أرسلنا رمز تحقق إلى (.+)$/, '📧 A verification code was sent to $1'],
  [/^جاري فتح تسجيل الدخول بواسطة (.+)\.\.\.$/, 'Opening $1 sign-in...'],
  [/^تعذر تسجيل الدخول بواسطة (.+)$/, 'Could not sign in with $1'],
  [/^تعذر إكمال تسجيل الدخول: (.+)$/, 'Could not complete sign-in: $1'],
  [/^✅ تم استيراد (\d+) روابط محفوظة$/, '✅ Imported $1 saved links'],
  [/^عدد الروابط المنتظرة في App Group: (\d+)$/, 'Pending links in App Group: $1'],
];
const BUILTIN_CATEGORY_EN = {'أفلام':'Movies','مسلسلات':'TV Shows','يوتيوب':'YouTube','تعليم':'Education','طبخ':'Cooking','مشتريات':'Shopping','أفكار':'Ideas','أخرى':'Other'};

Object.assign(I18N_EN, {
  'قراءة QR':'Scan QR',
  'قراءة رابط من QR':'Scan a link from QR',
  '⚠️ قراءة QR متاحة داخل تطبيق الآيفون':'⚠️ QR scanning is available in the iPhone app',
  '⚠️ قارئ QR غير متاح في هذا الإصدار':'⚠️ The QR scanner is unavailable in this build',
  '⚠️ هذا الجهاز لا يدعم قراءة QR':'⚠️ This device does not support QR scanning',
  'صلاحية الكاميرا مطلوبة لقراءة QR. فتح الإعدادات؟':'Camera access is required to scan QR codes. Open Settings?',
  '⚠️ اسمح باستخدام الكاميرا لقراءة QR':'⚠️ Allow camera access to scan QR codes',
  'ℹ️ لم يتم العثور على رمز QR':'ℹ️ No QR code was found',
  '⚠️ رمز QR لا يحتوي على رابط صالح':'⚠️ The QR code does not contain a valid link',
  '⚠️ تعذرت قراءة رمز QR':'⚠️ The QR code could not be scanned',
  '💎 LinkVault Pro':'💎 LinkVault Pro',
  '💎 الترقية إلى Pro':'💎 Upgrade to Pro',
  'استرجاع المشتريات':'Restore purchases',
  'الخطة المجانية':'Free plan',
  'شهري':'Monthly',
  'سنوي':'Annual',
  'مدى الحياة':'Lifetime',
  'شهريًا':'per month',
  'سنويًا':'per year',
  'دفعة واحدة':'one-time payment',
  'اختر الخطة المناسبة. السعر النهائي يظهر من App Store بعملة حسابك.':'Choose a plan. The final price is shown by the App Store in your account currency.',
  'روابط وأنواع غير محدودة':'Unlimited links and types',
  'إغلاق صفحة الاشتراك':'Close subscription page',
  '✅ تم تفعيل LinkVault Pro':'✅ LinkVault Pro activated',
  '✅ تم استرجاع مشترياتك':'✅ Your purchases were restored',
  'ℹ️ لا توجد مشتريات Pro مرتبطة بهذا الحساب':'ℹ️ No Pro purchases are linked to this account',
  '⚠️ تعذر استرجاع المشتريات':'⚠️ Purchases could not be restored',
  '⚠️ تعذر إكمال عملية الشراء':'⚠️ The purchase could not be completed',
  '⚠️ هذه الخطة غير مجهزة في RevenueCat':'⚠️ This plan is not configured in RevenueCat'
});

let languageChoice = STORE.get(LS_LANG, 'device') || 'device';
if(!['device','ar','en'].includes(languageChoice)) languageChoice = 'device';
let currentLanguage = 'en';
let languageObserver = null;
const i18nOriginalText = new WeakMap();
const i18nOriginalAttrs = new WeakMap();
const nativeAlert = window.alert.bind(window);
const nativeConfirm = window.confirm.bind(window);
const nativePrompt = window.prompt.bind(window);
function deviceLanguage(){ return String(navigator.language || navigator.languages?.[0] || '').toLowerCase().startsWith('ar') ? 'ar' : 'en'; }
function resolveLanguage(choice){ return choice === 'ar' ? 'ar' : choice === 'en' ? 'en' : deviceLanguage(); }
function translateUiCore(core){
  if(currentLanguage !== 'en' || !core) return core;
  if(Object.prototype.hasOwnProperty.call(I18N_EN, core)) return I18N_EN[core];
  const numbered = core.match(/^(\d+)\.\s*(أفلام|مسلسلات|يوتيوب|تعليم|طبخ|مشتريات|أفكار|أخرى)$/);
  if(numbered) return `${numbered[1]}. ${BUILTIN_CATEGORY_EN[numbered[2]] || numbered[2]}`;
  for(const [regex, replacement] of I18N_PATTERNS){
    if(regex.test(core)){
      let translated = core.replace(regex, replacement);
      for(const [arabic, english] of Object.entries(BUILTIN_CATEGORY_EN)) translated = translated.split(arabic).join(english);
      return translated;
    }
  }
  return core;
}
function translateUiText(value){
  const raw = String(value ?? '');
  const match = raw.match(/^(\s*)([\s\S]*?)(\s*)$/);
  if(!match) return raw;
  return match[1] + translateUiCore(match[2]) + match[3];
}
function translateTextNode(node, force=false){
  let original = i18nOriginalText.get(node);
  if(original === undefined){ original = node.nodeValue || ''; i18nOriginalText.set(node, original); }
  else if(!force){
    const expected = currentLanguage === 'en' ? translateUiText(original) : original;
    if((node.nodeValue || '') !== expected){ original = node.nodeValue || ''; i18nOriginalText.set(node, original); }
  }
  const target = currentLanguage === 'en' ? translateUiText(original) : original;
  if(node.nodeValue !== target) node.nodeValue = target;
}
function translateAttributes(el, force=false){
  const names = ['placeholder','title','aria-label'];
  let originals = i18nOriginalAttrs.get(el);
  if(!originals){ originals = {}; i18nOriginalAttrs.set(el, originals); }
  for(const name of names){
    if(!el.hasAttribute || !el.hasAttribute(name)) continue;
    let original = originals[name];
    const current = el.getAttribute(name) || '';
    if(original === undefined){ original = current; originals[name] = original; }
    else if(!force){
      const expected = currentLanguage === 'en' ? translateUiText(original) : original;
      if(current !== expected){ original = current; originals[name] = original; }
    }
    const target = currentLanguage === 'en' ? translateUiText(original) : original;
    if(current !== target) el.setAttribute(name, target);
  }
}
function translateTree(root=document.body, force=false){
  if(!root) return;
  if(root.nodeType === Node.TEXT_NODE){ translateTextNode(root, force); return; }
  if(root.nodeType !== Node.ELEMENT_NODE && root.nodeType !== Node.DOCUMENT_NODE && root.nodeType !== Node.DOCUMENT_FRAGMENT_NODE) return;
  if(root.nodeType === Node.ELEMENT_NODE) translateAttributes(root, force);
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_TEXT, {
    acceptNode(node){
      const parent = node.nodeType === Node.TEXT_NODE ? node.parentElement : node;
      if(parent && ['SCRIPT','STYLE','NOSCRIPT'].includes(parent.tagName)) return NodeFilter.FILTER_REJECT;
      return NodeFilter.FILTER_ACCEPT;
    }
  });
  let node;
  while((node = walker.nextNode())){
    if(node.nodeType === Node.TEXT_NODE) translateTextNode(node, force);
    else translateAttributes(node, force);
  }
}
async function syncLanguageToNative(){
  const plugin = getNativePlugin('PendingShare');
  if(!plugin || !plugin.setLanguage) return;
  try{ await plugin.setLanguage({ language:languageChoice }); }catch(e){ console.warn('Language sync to Share Extension failed', e); }
}
function applyLanguageChoice(choice, persist=true){
  languageChoice = ['device','ar','en'].includes(choice) ? choice : 'device';
  currentLanguage = resolveLanguage(languageChoice);
  if(persist) STORE.set(LS_LANG, languageChoice);
  document.documentElement.lang = currentLanguage;
  document.documentElement.dir = currentLanguage === 'ar' ? 'rtl' : 'ltr';
  document.title = currentLanguage === 'ar' ? 'LinkVault — مكتبة روابطك الذكية' : 'LinkVault — Your smart link library';
  const selector = $('languageSelect'); if(selector) selector.value = languageChoice;
  translateTree(document.body, true);
  syncLanguageToNative();
}
function initLanguage(){
  applyLanguageChoice(languageChoice, false);
  if(languageObserver) languageObserver.disconnect();
  languageObserver = new MutationObserver(records => {
    for(const record of records){
      if(record.type === 'characterData') translateTextNode(record.target, false);
      else if(record.type === 'attributes') translateAttributes(record.target, false);
      else for(const node of record.addedNodes) translateTree(node, false);
    }
  });
  languageObserver.observe(document.body, {subtree:true, childList:true, characterData:true, attributes:true, attributeFilter:['placeholder','title','aria-label']});
  window.alert = msg => nativeAlert(currentLanguage === 'en' ? translateUiText(msg) : msg);
  window.confirm = msg => nativeConfirm(currentLanguage === 'en' ? translateUiText(msg) : msg);
  window.prompt = (msg, value) => nativePrompt(currentLanguage === 'en' ? translateUiText(msg) : msg, value);
}


function $(id){ return document.getElementById(id); }
function uid(){ return (crypto.randomUUID ? crypto.randomUUID() : Date.now().toString(36)+Math.random().toString(36).slice(2)); }
function nowIso(){ return new Date().toISOString(); }
function escapeHtml(v){ return String(v ?? '').replace(/[&<>'"]/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[ch])); }
function normalizeUrl(v){ const s = String(v || '').trim(); if(!s) return ''; if(/^https?:\/\//i.test(s)) return s; if(/^www\./i.test(s)) return 'https://' + s; return s; }
function extractFirstUrl(text){ const m = String(text || '').match(/https?:\/\/[^\s]+/i); return m ? m[0].replace(/[\])}>,.]+$/,'') : ''; }
function normalizeLinks(items){ return (items || []).map(x => ({ id:x.id || uid(), title:x.title || '', url:x.url || '', cat:x.cat || x.category_name || 'أخرى', note:x.note || x.notes || '', trailer:x.trailer || x.trailer_url || '', thumbnail:x.thumbnail || x.thumbnail_url || '', platform:x.platform || detectPlatform(x.url || '').label, ts:x.ts || (x.created_at ? new Date(x.created_at).getTime() : Date.now()), updatedAt:x.updatedAt || x.updated_at || nowIso(), favorite:!!(x.favorite || x.is_favorite) })).filter(x => x.url); }
function normalizeCategories(list){ const seen=[]; (list||[]).map(x=>String(x||'').trim()).filter(Boolean).forEach(c=>{ if(c!==OTHER_CAT && !seen.includes(c)) seen.push(c); }); seen.push(OTHER_CAT); return seen; }
function accountStoreKey(base,userId){ return base + '_user_' + userId; }
function persistAccountData(userId){ if(!userId) return; cats=normalizeCategories(cats); STORE.set(accountStoreKey(LS_LINKS,userId),links); STORE.set(accountStoreKey(LS_CATS,userId),cats); STORE.set(accountStoreKey(LS_PROTECTED_CATS,userId),[...protectedCats]); }
function activateCloudAccount(user){ if(!user?.id) return; const userId=user.id; const saved=STORE.get(accountStoreKey(LS_LINKS,userId),null); if(saved===null){ links=[]; cats=normalizeCategories(DEFAULT_CATS); protectedCats=new Set(DEFAULT_CATS.filter(c=>c!==OTHER_CAT)); } else { links=normalizeLinks(saved); cats=normalizeCategories(STORE.get(accountStoreKey(LS_CATS,userId),DEFAULT_CATS)); protectedCats=new Set(STORE.get(accountStoreKey(LS_PROTECTED_CATS,userId),DEFAULT_CATS.filter(c=>c!==OTHER_CAT))); } persistAccountData(userId); STORE.set(LS_ACTIVE_CLOUD_USER,userId); currentCat='all'; selectedIds.clear(); saveLocal(); renderTabs(); renderList(); }
function activateGuestAccount(){ links=normalizeLinks(STORE.get(LS_LINKS,[])); cats=normalizeCategories(STORE.get(LS_CATS,DEFAULT_CATS)); protectedCats=new Set(STORE.get(LS_PROTECTED_CATS,DEFAULT_CATS.filter(c=>c!==OTHER_CAT))); currentCat='all'; selectedIds.clear(); renderTabs(); renderList(); }
function saveLocal(){ cats=normalizeCategories(cats); if(cloudUser?.id) persistAccountData(cloudUser.id); else { STORE.set(LS_LINKS,links); STORE.set(LS_CATS,cats); STORE.set(LS_PROTECTED_CATS,[...protectedCats]); } syncCategoriesToNative().catch(()=>{}); }
function getSettings(){ const fileCfg = window.LINKVAULT_CONFIG || {}; const local = STORE.get(LS_SETTINGS, {}); return { SUPABASE_URL: local.SUPABASE_URL || fileCfg.SUPABASE_URL || '', SUPABASE_ANON_KEY: local.SUPABASE_ANON_KEY || fileCfg.SUPABASE_ANON_KEY || '', BACKEND_URL: local.BACKEND_URL || fileCfg.BACKEND_URL || '' }; }
function setSettings(v){ STORE.set(LS_SETTINGS, v); }
function saveUiPrefs(){ uiPrefs = { theme:currentTheme, viewMode }; STORE.set(LS_UI, uiPrefs); }
function updateThemeMeta(){ const colors = { dark:'#0d0d14', light:'#f4f6fb', beige:'#eee7dc' }; const meta = document.querySelector('meta[name="theme-color"]'); if(meta) meta.setAttribute('content', colors[currentTheme] || colors.dark); }
function applyTheme(theme, persist=true){ currentTheme = ['dark','light','beige'].includes(theme) ? theme : 'dark'; document.documentElement.dataset.theme = currentTheme; updateThemeMeta(); document.querySelectorAll('[data-theme]').forEach(btn => btn.classList.toggle('active', btn.dataset.theme === currentTheme)); if(persist) saveUiPrefs(); }
function setViewMode(mode){ viewMode = ['cards','compact','grid'].includes(mode) ? mode : 'cards'; saveUiPrefs(); document.querySelectorAll('[data-view]').forEach(btn => btn.classList.toggle('active', btn.dataset.view === viewMode)); renderList(); }
function isCommercialFree(){ return APP_EDITION === 'commercial' && !isPro; }
function defaultCustomCategories(){ return DEFAULT_CATS.filter(c=>c!==OTHER_CAT); }
function customCategoriesCount(){ const base = new Set(defaultCustomCategories()); return cats.filter(c=>c!==OTHER_CAT && !base.has(c)).length; }
function showUpgradePrompt(message){ toast(message); if(APP_EDITION === 'commercial') setTimeout(openPaywall, 260); }
function canAddLink(){ if(!isCommercialFree()) return true; if(links.length < PLAN_LIMITS.freeLinks) return true; showUpgradePrompt(`🔒 النسخة المجانية تسمح بـ ${PLAN_LIMITS.freeLinks} روابط فقط`); return false; }
function canAddCustomCategory(name){ if(!isCommercialFree()) return true; const base = new Set(defaultCustomCategories()); if(base.has(name) || cats.includes(name)) return true; if(customCategoriesCount() < PLAN_LIMITS.freeCustomCategories) return true; showUpgradePrompt(`🔒 النسخة المجانية تسمح بـ ${PLAN_LIMITS.freeCustomCategories} أنواع إضافية فقط`); return false; }
function getVisibleLinks(){ const q = $('searchInp').value.trim().toLowerCase(); let data = [...links].sort((a,b) => (b.ts || 0) - (a.ts || 0)); if(currentCat === FAVORITES_FILTER) data = data.filter(l => l.favorite); else if(currentCat !== 'all') data = data.filter(l => l.cat === currentCat); if(q) data = data.filter(l => [l.title,l.url,l.note,l.cat,l.platform].some(v => String(v||'').toLowerCase().includes(q))); return data; }
function setSelectionMode(enabled){ selectionMode = !!enabled; if(!selectionMode) selectedIds.clear(); $('btnSelectMode').classList.toggle('active', selectionMode); $('btnSelectMode').textContent = selectionMode ? '✕ إنهاء' : '☑ تحديد'; $('selectionBar').classList.toggle('show', selectionMode); renderList(); }
function toggleSelected(id){ if(selectedIds.has(id)) selectedIds.delete(id); else selectedIds.add(id); updateSelectionUi(); const card = document.querySelector(`.link-card[data-id="${CSS.escape(id)}"]`); if(card) card.classList.toggle('selected', selectedIds.has(id)); }
function updateSelectionUi(){ selectedIds = new Set([...selectedIds].filter(id => links.some(l => l.id === id))); $('selectionCount').textContent = `${selectedIds.size} محدد`; $('btnDeleteSelected').disabled = selectedIds.size === 0; }


function getNativePlugin(name){
  const cap = window.Capacitor;
  if(!cap) return null;
  if(cap.Plugins && cap.Plugins[name]) return cap.Plugins[name];
  if(typeof cap.registerPlugin === 'function'){
    try{
      const plugin = cap.registerPlugin(name);
      cap.Plugins = cap.Plugins || {};
      cap.Plugins[name] = plugin;
      return plugin;
    }catch(e){
      return (cap.Plugins && cap.Plugins[name]) || null;
    }
  }
  return null;
}

function qrCandidateToUrl(rawValue){
  const raw = String(rawValue || '').trim();
  const extracted = extractFirstUrl(raw);
  return normalizeUrl(extracted || raw);
}
async function scanQrCode(){
  try{
    if(!isNativeApp()){
      toast('⚠️ قراءة QR متاحة داخل تطبيق الآيفون');
      return;
    }
    const scanner = getNativePlugin('BarcodeScanner');
    if(!scanner || !scanner.scan){
      toast('⚠️ قارئ QR غير متاح في هذا الإصدار');
      return;
    }
    if(scanner.isSupported){
      const support = await scanner.isSupported();
      if(support && support.supported === false){
        toast('⚠️ هذا الجهاز لا يدعم قراءة QR');
        return;
      }
    }
    const platform = window.Capacitor?.getPlatform?.() || '';
    if(platform === 'ios' && scanner.requestPermissions){
      const permissions = await scanner.requestPermissions();
      const cameraState = permissions?.camera;
      if(cameraState !== 'granted' && cameraState !== 'limited'){
        if(cameraState === 'denied' && scanner.openSettings && confirm('صلاحية الكاميرا مطلوبة لقراءة QR. فتح الإعدادات؟')) await scanner.openSettings();
        else toast('⚠️ اسمح باستخدام الكاميرا لقراءة QR');
        return;
      }
    }
    const result = await scanner.scan({ formats:['QR_CODE'] });
    const rawValue = result?.barcodes?.[0]?.rawValue || result?.barcodes?.[0]?.displayValue || '';
    if(!rawValue){ toast('ℹ️ لم يتم العثور على رمز QR'); return; }
    const url = qrCandidateToUrl(rawValue);
    if(!/^https?:\/\//i.test(url)){
      toast('⚠️ رمز QR لا يحتوي على رابط صالح');
      return;
    }
    closeSettings();
    openAddModal({ url });
    setTimeout(() => fetchMetadata().catch(()=>{}), 260);
  }catch(e){
    const cancelled = String(e?.message || e || '').toLowerCase().includes('cancel');
    if(!cancelled){
      console.warn('QR scan failed', e);
      toast('⚠️ تعذرت قراءة رمز QR');
    }
  }
}

function getRevenueCatConfig(){
  const cfg = window.LINKVAULT_CONFIG || {};
  return {
    apiKey:String(cfg.REVENUECAT_IOS_API_KEY || '').trim(),
    entitlementId:String(cfg.REVENUECAT_ENTITLEMENT_ID || 'pro').trim() || 'pro',
    offeringId:String(cfg.REVENUECAT_OFFERING_ID || '').trim()
  };
}
function hasRevenueCatKey(){
  const key = getRevenueCatConfig().apiKey;
  return /^appl_[A-Za-z0-9_-]{8,}$/.test(key) && !key.includes('REPLACE');
}
function revenueCatPlugin(){ return getNativePlugin('Purchases'); }
function activeEntitlement(customerInfo){
  const active = customerInfo?.entitlements?.active || {};
  const configured = active[getRevenueCatConfig().entitlementId];
  if(configured?.isActive) return configured;
  return Object.values(active).find(item => item?.isActive) || null;
}
function customerHasPro(customerInfo){ return !!activeEntitlement(customerInfo); }
function updateProUi(){
  const section = $('proSettingsSection');
  if(section) section.hidden = APP_EDITION !== 'commercial';
  const status = $('proStatus');
  const button = $('btnOpenPaywall');
  if(APP_EDITION !== 'commercial') return;
  if(isPro){
    const entitlement = activeEntitlement(rcCustomerInfo);
    let detail = 'Pro مفعّل';
    if(entitlement?.expirationDate) detail += ` حتى ${new Date(entitlement.expirationDate).toLocaleDateString(currentLanguage === 'ar' ? 'ar-KW' : 'en-US')}`;
    else if(entitlement) detail += ' — مدى الحياة';
    if(status){ status.textContent = `✅ ${detail}`; status.className = 'pro-status active'; }
    if(button){ button.textContent = '✅ اشتراك Pro مفعّل'; button.disabled = true; }
  }else{
    if(status){ status.textContent = `الخطة المجانية: حتى ${PLAN_LIMITS.freeLinks} روابط و${PLAN_LIMITS.freeCustomCategories} أنواع إضافية`; status.className = 'pro-status'; }
    if(button){ button.textContent = '💎 الترقية إلى Pro'; button.disabled = false; }
  }
}
function applyRevenueCatCustomerInfo(customerInfo){
  rcCustomerInfo = customerInfo || null;
  isPro = APP_EDITION === 'full' || customerHasPro(customerInfo);
  updateProUi();
}
function packagePrice(aPackage, fallback){ return aPackage?.product?.priceString || fallback; }
function resolveOffering(offerings){
  const cfg = getRevenueCatConfig();
  return (cfg.offeringId && offerings?.all?.[cfg.offeringId]) || offerings?.current || Object.values(offerings?.all || {})[0] || null;
}
function renderRevenueCatOffering(offering){
  rcPackages = {
    monthly: offering?.monthly || offering?.availablePackages?.find(p => p.packageType === 'MONTHLY') || null,
    annual: offering?.annual || offering?.availablePackages?.find(p => p.packageType === 'ANNUAL') || null,
    lifetime: offering?.lifetime || offering?.availablePackages?.find(p => p.packageType === 'LIFETIME') || null
  };
  const prices = {
    monthly:packagePrice(rcPackages.monthly, '$1.99'),
    annual:packagePrice(rcPackages.annual, '$14.99'),
    lifetime:packagePrice(rcPackages.lifetime, '$29.99')
  };
  const map = { monthly:'paywallMonthlyPrice', annual:'paywallAnnualPrice', lifetime:'paywallLifetimePrice' };
  Object.entries(map).forEach(([kind,id]) => { const el=$(id); if(el) el.textContent=prices[kind]; });
  document.querySelectorAll('[data-rc-package]').forEach(btn => { btn.disabled = !rcPackages[btn.dataset.rcPackage] || !rcReady; });
  const msg = $('paywallMessage');
  if(msg) msg.textContent = offering ? 'اختر الخطة المناسبة. السعر النهائي يظهر من App Store بعملة حسابك.' : 'لم يتم العثور على باقات في RevenueCat.';
}
async function loadRevenueCatOfferings(){
  if(APP_EDITION !== 'commercial' || !rcReady) return null;
  try{
    const offerings = await revenueCatPlugin().getOfferings();
    rcOffering = resolveOffering(offerings);
    renderRevenueCatOffering(rcOffering);
    return rcOffering;
  }catch(e){
    console.warn('RevenueCat offerings failed', e);
    const msg=$('paywallMessage'); if(msg) msg.textContent='تعذر تحميل الأسعار. تأكد من إعداد Offering في RevenueCat.';
    return null;
  }
}
async function refreshRevenueCatStatus(){
  if(APP_EDITION !== 'commercial' || !rcReady) return;
  try{
    const result = await revenueCatPlugin().getCustomerInfo();
    applyRevenueCatCustomerInfo(result?.customerInfo);
  }catch(e){ console.warn('RevenueCat customer info failed', e); }
}
async function initRevenueCat(){
  updateProUi();
  if(APP_EDITION !== 'commercial') return;
  if(!isNativeApp()){
    const status=$('proStatus'); if(status) status.textContent='الشراء متاح داخل تطبيق الآيفون.';
    return;
  }
  if(!hasRevenueCatKey()){
    const status=$('proStatus'); if(status){ status.textContent='⚠️ أضف RevenueCat Public SDK Key لتفعيل الشراء.'; status.className='pro-status warning'; }
    return;
  }
  const purchases = revenueCatPlugin();
  if(!purchases?.configure){
    const status=$('proStatus'); if(status) status.textContent='⚠️ إضافة RevenueCat غير موجودة في البناء.';
    return;
  }
  try{
    await purchases.configure({ apiKey:getRevenueCatConfig().apiKey, appUserID:cloudUser?.id || null });
    rcReady = true;
    try{
      await purchases.addCustomerInfoUpdateListener(info => applyRevenueCatCustomerInfo(info));
    }catch(e){ console.warn('RevenueCat listener unavailable', e); }
    await Promise.all([refreshRevenueCatStatus(), loadRevenueCatOfferings()]);
  }catch(e){
    console.warn('RevenueCat configuration failed', e);
    const status=$('proStatus'); if(status){ status.textContent='⚠️ تعذر تشغيل RevenueCat. راجع المفتاح وإعدادات المنتجات.'; status.className='pro-status warning'; }
  }
}
async function identifyRevenueCatUser(userId){
  if(!rcReady || !userId) return;
  try{
    const result = await revenueCatPlugin().logIn({ appUserID:userId });
    applyRevenueCatCustomerInfo(result?.customerInfo);
  }catch(e){ console.warn('RevenueCat login failed', e); }
}
async function logoutRevenueCatUser(){
  if(!rcReady) return;
  try{
    const result = await revenueCatPlugin().logOut();
    applyRevenueCatCustomerInfo(result?.customerInfo);
  }catch(e){ console.warn('RevenueCat logout failed', e); }
}
async function openPaywall(){
  if(APP_EDITION !== 'commercial') return;
  $('paywallOverlay').classList.add('open');
  updateProUi();
  if(!hasRevenueCatKey()){
    $('paywallMessage').textContent = 'أضف RevenueCat Public SDK Key في app-config.js أو متغير Codemagic لتفعيل الدفع.';
    document.querySelectorAll('[data-rc-package]').forEach(btn => btn.disabled = true);
    return;
  }
  if(!rcReady) await initRevenueCat();
  if(rcReady) await loadRevenueCatOfferings();
}
function closePaywall(){ $('paywallOverlay').classList.remove('open'); }
async function purchaseRevenueCatPackage(kind){
  const aPackage = rcPackages[kind];
  if(!rcReady || !aPackage){ toast('⚠️ هذه الخطة غير مجهزة في RevenueCat'); return; }
  const button = document.querySelector(`[data-rc-package="${kind}"]`);
  try{
    if(button) button.disabled = true;
    const result = await revenueCatPlugin().purchasePackage({ aPackage });
    applyRevenueCatCustomerInfo(result?.customerInfo);
    if(isPro){ closePaywall(); toast('✅ تم تفعيل LinkVault Pro'); }
    else toast('⚠️ تمت العملية لكن صلاحية Pro غير مفعلة. راجع Entitlement في RevenueCat.');
  }catch(e){
    const cancelled = !!(e?.userCancelled || e?.userInfo?.userCancelled || String(e?.message || '').toLowerCase().includes('cancel'));
    if(!cancelled){ console.warn('RevenueCat purchase failed', e); toast('⚠️ تعذر إكمال عملية الشراء'); }
  }finally{
    if(button) button.disabled = !rcPackages[kind] || !rcReady;
  }
}
async function restoreRevenueCatPurchases(){
  if(APP_EDITION !== 'commercial') return;
  if(!rcReady){ await initRevenueCat(); if(!rcReady) return; }
  try{
    const result = await revenueCatPlugin().restorePurchases();
    applyRevenueCatCustomerInfo(result?.customerInfo);
    toast(isPro ? '✅ تم استرجاع مشترياتك' : 'ℹ️ لا توجد مشتريات Pro مرتبطة بهذا الحساب');
    if(isPro) closePaywall();
  }catch(e){ console.warn('RevenueCat restore failed', e); toast('⚠️ تعذر استرجاع المشتريات'); }
}

function fallbackTitleFor(url, title='', text=''){
  const cleanTitle = String(title || '').trim();
  if(cleanTitle && cleanTitle !== url) return cleanTitle.slice(0, 180);
  const withoutUrl = String(text || '').replace(url || '', '').trim().replace(/\s+/g, ' ');
  if(withoutUrl) return withoutUrl.slice(0, 120);
  const d = domainOf(url);
  return d || url || 'رابط محفوظ';
}
function normalizeArabicSearchText(value){
  return String(value || '')
    .toLowerCase()
    .replace(/[ًٌٍَُِّْـ]/g, '')
    .replace(/[إأآ]/g, 'ا')
    .replace(/ة/g, 'ه')
    .replace(/ى/g, 'ي')
    .replace(/ؤ/g, 'و')
    .replace(/ئ/g, 'ي')
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}
function categoryExists(name){ return cats.includes(name); }
function fallbackCategory(){ return categoryExists('أخرى') ? 'أخرى' : (cats[0] || 'أخرى'); }
function suggestCategoryForLink({ url='', title='', text='' } = {}){
  const haystack = normalizeArabicSearchText([title, text, url, domainOf(url)].filter(Boolean).join(' '));
  if(haystack){
    for(const rule of CATEGORY_RULES){
      if(!categoryExists(rule.cat)) continue;
      const matched = rule.words.some(w => haystack.includes(normalizeArabicSearchText(w)));
      if(matched) return rule.cat;
    }
  }
  const platform = detectPlatform(url).id;
  if(platform === 'youtube' && categoryExists('يوتيوب')) return 'يوتيوب';
  return fallbackCategory();
}
function upgradeExistingOtherCategories(){
  let changed = false;
  links = links.map(l => {
    if(!l || !l.url) return l;
    const current = l.cat || '';
    if(current && current !== 'أخرى') return l;
    const suggested = suggestCategoryForLink({ url:l.url, title:l.title, text:l.note });
    if(suggested && suggested !== current && suggested !== 'أخرى'){
      changed = true;
      return { ...l, cat:suggested, updatedAt:l.updatedAt || nowIso() };
    }
    return l;
  });
  return changed;
}
function withTimeout(promise, ms, fallback={}){
  return Promise.race([
    promise,
    new Promise(resolve => setTimeout(() => resolve(fallback), ms))
  ]);
}
async function getMetadataQuick(url){
  try{
    const data = await withTimeout(getMetadata(url), 2800, {});
    return data || {};
  }catch(e){
    return {};
  }
}
function canonicalUrl(url){ return String(url || '').trim().replace(/\/$/, '').toLowerCase(); }
async function saveSharedLinkDirectly(payload){
  const rawUrl = payload.url || extractFirstUrl(payload.text || '') || '';
  const url = normalizeUrl(rawUrl);
  const text = String(payload.text || '').trim();
  const manualNote = String(payload.note || '').trim();
  let manualCat = String(payload.cat || payload.category || '').trim();
  if(!url || !/^https?:\/\//i.test(url)) return false;

  if(manualCat && !cats.includes(manualCat)){
    if(!canAddCustomCategory(manualCat)) manualCat = '';
    else cats = normalizeCategories([...cats, manualCat]);
  }

  const metadata = await getMetadataQuick(url);
  const title = fallbackTitleFor(url, payload.title || metadata.title, [text, manualNote, metadata.title].filter(Boolean).join(' '));
  const categoryText = [text, manualNote, payload.title, metadata.title, manualCat].filter(Boolean).join(' ');
  const suggestedCat = suggestCategoryForLink({ url, title, text: categoryText });
  const cat = manualCat || suggestedCat;
  const thumbnail = payload.thumbnail || metadata.image || '';
  const platform = payload.platform || metadata.platform || detectPlatform(url).label;
  const note = manualNote || (text && text !== url ? text : '');

  const existing = links.find(l => canonicalUrl(l.url) === canonicalUrl(url));
  if(existing){
    let changed = false;
    const oldTitleLooksGeneric = !existing.title || existing.title === existing.url || existing.title === domainOf(existing.url);
    if((oldTitleLooksGeneric || manualCat) && title && existing.title !== title){ existing.title = title; changed = true; }
    if(((manualCat && existing.cat !== manualCat) || ((!existing.cat || existing.cat === 'أخرى') && cat && cat !== 'أخرى'))){ existing.cat = cat; changed = true; }
    if(note && (!existing.note || existing.note !== note)){ existing.note = note; changed = true; }
    if(!existing.thumbnail && thumbnail){ existing.thumbnail = thumbnail; changed = true; }
    if(!existing.platform && platform){ existing.platform = platform; changed = true; }
    if(changed){
      existing.updatedAt = nowIso();
      upsertLinkCloud(existing).catch(e => console.warn('Cloud upsert failed after duplicate share update', e));
    }
    currentCat = 'all';
    saveLocal();
    renderTabs();
    renderList();
    toast(changed ? '✅ الرابط محفوظ مسبقًا وتم تحديث بياناته' : 'ℹ️ الرابط محفوظ مسبقًا');
    return true;
  }

  if(!canAddLink()) return false;
  const item = {
    id: uid(),
    url,
    title,
    cat,
    trailer: '',
    note,
    thumbnail,
    platform,
    favorite:false,
    ts: Date.now(),
    updatedAt: nowIso()
  };
  links.unshift(item);
  currentCat = 'all';
  saveLocal();
  renderTabs();
  renderList();
  toast(`✅ تم حفظ الرابط في ${cat}`);
  upsertLinkCloud(item).catch(e => console.warn('Cloud upsert failed after local share save', e));
  return true;
}


async function syncCategoriesToNative(){
  const plugin = getNativePlugin('PendingShare');
  if(!plugin || !plugin.setCategories) return;
  await plugin.setCategories({ categories: normalizeCategories(cats) });
}

const PLATFORMS = [
  { id:'youtube', test:u=>/youtube\.com|youtu\.be/.test(u), color:'#FF0000', label:'YouTube' },
  { id:'instagram', test:u=>/instagram\.com/.test(u), color:'ig', label:'Instagram' },
  { id:'facebook', test:u=>/facebook\.com|fb\.com/.test(u), color:'#1877F2', label:'Facebook' },
  { id:'tiktok', test:u=>/tiktok\.com/.test(u), color:'#010101', label:'TikTok' },
  { id:'twitter', test:u=>/twitter\.com|x\.com/.test(u), color:'#000000', label:'X / Twitter' },
  { id:'reddit', test:u=>/reddit\.com/.test(u), color:'#FF4500', label:'Reddit' },
  { id:'vimeo', test:u=>/vimeo\.com/.test(u), color:'#1AB7EA', label:'Vimeo' },
  { id:'web', test:()=>true, color:'#6b6b90', label:'Web' }
];
function detectPlatform(url){ const s = String(url || '').toLowerCase(); return PLATFORMS.find(p => p.test(s)) || PLATFORMS.at(-1); }
function accentColor(url){ const p = detectPlatform(url); if(p.color === 'ig') return 'linear-gradient(90deg,#fdf497,#fd5949,#d6249f,#285AEB)'; return p.color; }
function domainOf(url){ try { return new URL(url).hostname.replace(/^www\./,''); } catch(e){ return ''; } }
function platformLogo(url){
  const p = detectPlatform(url);
  if(p.id === 'instagram') return `<svg viewBox="0 0 42 42"><defs><radialGradient id="ig" cx="30%" cy="107%" r="130%"><stop offset="0%" stop-color="#fdf497"/><stop offset="45%" stop-color="#fd5949"/><stop offset="60%" stop-color="#d6249f"/><stop offset="90%" stop-color="#285AEB"/></radialGradient></defs><rect width="42" height="42" rx="11" fill="url(#ig)"/><rect x="8" y="8" width="26" height="26" rx="8" fill="none" stroke="white" stroke-width="2.4"/><circle cx="21" cy="21" r="6.2" fill="none" stroke="white" stroke-width="2.4"/><circle cx="29" cy="13" r="1.8" fill="white"/></svg>`;
  if(p.id === 'youtube') return `<svg viewBox="0 0 42 42"><rect width="42" height="42" rx="11" fill="#FF0000"/><path d="M33.5 15s-.3-2-1.2-2.9c-1.1-1.2-2.4-1.2-3-1.3-4.1-.3-10.3-.3-10.3-.3s-6.2 0-10.3.3c-.6.1-1.9.1-3 1.3C4.8 13 4.5 15 4.5 15s-.3 2.4-.3 4.8v2c0 2.4.3 4.8.3 4.8s.3 2 1.2 2.9c1.1 1.2 2.6 1.2 3.2 1.3 2.3.2 10.1.3 10.1.3s6.2 0 10.3-.3c.6-.1 1.9-.1 3-1.3.9-.9 1.2-2.9 1.2-2.9s.3-2.4.3-4.8v-2c0-2.4-.3-4.8-.3-4.8zM17.4 25.6v-9.3l8.8 4.7-8.8 4.6z" fill="white"/></svg>`;
  if(p.id === 'facebook') return `<svg viewBox="0 0 42 42"><rect width="42" height="42" rx="11" fill="#1877F2"/><path d="M24 36V23.5h4.1l.7-5H24v-3.2c0-1.5.7-2.8 2.9-2.8h2.2V8.2S27.2 7.9 25.4 7.9c-4.4 0-7.3 2.7-7.3 7.5v3.1h-4.9v5h4.9V36H24z" fill="white"/></svg>`;
  if(p.id === 'tiktok') return `<svg viewBox="0 0 42 42"><rect width="42" height="42" rx="11" fill="#010101"/><path d="M30.6 12.6c-2.3 0-4.1-1.7-4.4-4h-4.3v18.1a3.9 3.9 0 1 1-3.9-3.9c.4 0 .8.1 1.2.2v-4.4a8.3 8.3 0 1 0 7.1 8.2v-9.2c1.3.9 2.8 1.4 4.4 1.4v-6.4z" fill="white"/></svg>`;
  if(p.id === 'twitter') return `<svg viewBox="0 0 42 42"><rect width="42" height="42" rx="11" fill="#000"/><path d="M9 9h7.4l6 8.2L29.4 9h3.1l-8.7 10.1L34 33h-7.4l-6.7-9.1L12.1 33H9l9.5-11.1L9 9zm5.4 2.4l13.4 19.2h1.8L16.2 11.4h-1.8z" fill="white"/></svg>`;
  if(p.id === 'reddit') return `<svg viewBox="0 0 42 42"><rect width="42" height="42" rx="11" fill="#FF4500"/><circle cx="21" cy="22" r="10" fill="white"/><circle cx="17.5" cy="22" r="1.5" fill="#FF4500"/><circle cx="24.5" cy="22" r="1.5" fill="#FF4500"/><path d="M17.8 26.3c2 1.5 4.4 1.5 6.4 0" stroke="#FF4500" stroke-width="1.4" fill="none" stroke-linecap="round"/><circle cx="32" cy="15" r="3" fill="white"/><path d="M23.5 13.2c2.7-2 5.5-1.4 7.5.9" stroke="white" stroke-width="1.5" fill="none"/></svg>`;
  const d = domainOf(url); const initials = (d || 'WEB').slice(0,2).toUpperCase();
  return `<svg viewBox="0 0 42 42"><rect width="42" height="42" rx="11" fill="${p.color}"/><text x="21" y="27" font-size="13" font-weight="900" text-anchor="middle" fill="white">${escapeHtml(initials)}</text></svg>`;
}

function renderTabs(){
  const bar = $('tabsBar');
  const favCount = links.filter(l=>l.favorite).length;
  const selectedType = currentCat === 'all' || cats.includes(currentCat) ? currentCat : 'all';
  const options = cats.map(c => `<option value="${escapeHtml(c)}" ${selectedType===c?'selected':''}>${escapeHtml(c)}</option>`).join('');
  bar.innerHTML = `<div class="type-filter-wrap"><select class="type-filter-select" id="typeFilterSelect" aria-label="قائمة النوع"><option value="all" ${selectedType==='all'?'selected':''}>كل الأنواع</option>${options}</select></div>` +
    `<button class="favorite-filter-btn ${currentCat===FAVORITES_FILTER?'active':''}" id="btnFavoritesFilter">⭐ المفضلة${favCount ? ' ' + favCount : ''}</button>` +
    `<button class="manage-cats-btn" id="btnManageCats" title="إدارة الأنواع" aria-label="إدارة الأنواع">⚙️ إدارة</button>`;
  $('typeFilterSelect').addEventListener('change', e => { currentCat = e.target.value; renderTabs(); renderList(); });
  $('btnFavoritesFilter').addEventListener('click', () => { currentCat = currentCat === FAVORITES_FILTER ? 'all' : FAVORITES_FILTER; renderTabs(); renderList(); });
  $('btnManageCats').addEventListener('click', openCatModal);
}
function renderList(){
  const q = $('searchInp').value.trim().toLowerCase();
  const data = getVisibleLinks();
  const el = $('mainList');
  document.querySelectorAll('[data-view]').forEach(btn => btn.classList.toggle('active', btn.dataset.view === viewMode));
  const stats = `<div class="summary-row"><div class="stat-card"><div class="stat-num">${links.length}</div><div class="stat-label">رابط</div></div><div class="stat-card"><div class="stat-num">${cats.length}</div><div class="stat-label">تصنيف</div></div><div class="stat-card"><div class="stat-num">${links.filter(x=>x.trailer).length}</div><div class="stat-label">تريلر</div></div></div>`;
  el.classList.toggle('selection-active', selectionMode);
  if(!data.length){ el.innerHTML = stats + `<div class="empty-state"><div class="empty-icon">🔗</div><h3>${q ? 'لا نتائج' : 'لا يوجد روابط بعد'}</h3><p>${q ? 'جرب كلمة بحث مختلفة' : 'اضغط + لإضافة رابط جديد<br>أو شاركه من أي تطبيق آخر'}</p></div>`; updateSelectionUi(); return; }
  const cards = data.map(l => {
    const platform = detectPlatform(l.url);
    const selected = selectedIds.has(l.id);
    return `<div class="link-card card-open-hint ${selected?'selected':''}" data-id="${escapeHtml(l.id)}"><button class="select-check" data-select-id="${escapeHtml(l.id)}" aria-label="تحديد الرابط">✓</button><div class="card-accent" style="background:${accentColor(l.url)}"></div><div class="card-body"><div class="card-top"><div class="platform-logo">${platformLogo(l.url)}</div><div class="card-info"><div class="card-title">${escapeHtml(l.title)}</div><div class="card-url">${escapeHtml(l.url)}</div></div><div class="card-actions"><button class="card-btn fav" data-id="${escapeHtml(l.id)}" data-action="fav" title="المفضلة"><span class="btn-icon">${l.favorite?'★':'☆'}</span><span class="btn-label">مفضلة</span></button><button class="card-btn share" data-id="${escapeHtml(l.id)}" data-action="share" title="مشاركة"><span class="btn-icon">📤</span><span class="btn-label">مشاركة</span></button><button class="card-btn trailer" data-id="${escapeHtml(l.id)}" data-action="trailer" title="التريلر"><span class="btn-icon">🎬</span><span class="btn-label">تريلر</span></button><button class="card-btn edit" data-id="${escapeHtml(l.id)}" data-action="edit" title="تعديل"><span class="btn-icon">✏️</span><span class="btn-label">تعديل</span></button><button class="card-btn del" data-id="${escapeHtml(l.id)}" data-action="del" title="حذف"><span class="btn-icon">🗑</span><span class="btn-label">حذف</span></button></div></div>${l.thumbnail ? `<div class="thumb-row"><img src="${escapeHtml(l.thumbnail)}" alt="صورة الرابط" loading="lazy"></div>` : ''}${l.note ? `<div class="card-note">📌 ${escapeHtml(l.note)}</div>` : ''}${l.trailer ? `<div class="trailer-row"><div class="t-icon">🎬</div><div class="t-info"><div class="t-title">تريلر</div><div class="t-url">${escapeHtml(l.trailer)}</div></div><a href="${escapeHtml(l.trailer)}" target="_blank" rel="noopener">▶ شاهد</a></div>` : ''}<div class="card-meta"><span class="cat-badge">${escapeHtml(l.cat)}</span><span class="platform-badge">${escapeHtml(platform.label)}</span><span class="card-date">${new Date(l.ts).toLocaleDateString(currentLanguage === 'ar' ? 'ar-KW' : 'en-US',{day:'numeric',month:'short'})}</span></div></div></div>`;
  }).join('');
  el.innerHTML = stats + `<div class="links-container view-${viewMode}">${cards}</div>`;
  el.querySelectorAll('.link-card').forEach(card => card.addEventListener('click', e => {
    if(e.target.closest('[data-action],a,button,input,textarea,select')) return;
    const id = card.dataset.id;
    if(selectionMode){ toggleSelected(id); return; }
    const l = links.find(x => x.id === id);
    if(l) window.open(l.url, '_blank');
  }));
  el.querySelectorAll('[data-select-id]').forEach(btn => btn.addEventListener('click', e => { e.stopPropagation(); toggleSelected(btn.dataset.selectId); }));
  el.querySelectorAll('[data-action]').forEach(btn => btn.addEventListener('click', async e => {
    e.stopPropagation();
    if(selectionMode){ toggleSelected(btn.dataset.id); return; }
    const id = btn.dataset.id;
    const action = btn.dataset.action;
    const l = links.find(x => x.id === id);
    if(!l) return;
    if(action === 'fav') { l.favorite = !l.favorite; l.updatedAt = nowIso(); saveLocal(); renderTabs(); renderList(); upsertLinkCloud(l).catch(e=>console.warn('Cloud favorite update failed', e)); return; }
    if(action === 'share') await shareLink(l);
    if(action === 'trailer') { if(l.trailer) window.open(l.trailer, '_blank'); else { openEdit(id); setTimeout(()=>$('btnTrailer').click(), 150); } }
    if(action === 'edit') openEdit(id);
    if(action === 'del') await deleteLink(id);
  }));
  updateSelectionUi();
}

function openAddModal(prefill={}){
  editId = null;
  $('sheetTitle').textContent = '➕ إضافة رابط جديد';
  $('inpUrl').value = prefill.url || '';
  $('inpTitle').value = prefill.title || '';
  $('inpTrailer').value = prefill.trailer || '';
  $('inpThumb').value = prefill.thumbnail || '';
  $('inpNote').value = prefill.note || '';
  $('aiStatus').textContent = '';
  populateCatSelect(prefill.cat || suggestCategoryForLink({ url:prefill.url || '', title:prefill.title || '', text:prefill.note || '' }) || cats[0]);
  updatePlatformField();
  $('overlay').classList.add('open');
  setTimeout(() => $('inpTitle').focus(), 150);
}
function openEdit(id){
  const l = links.find(x => x.id === id); if(!l) return;
  editId = id;
  $('sheetTitle').textContent = '✏️ تعديل الرابط';
  $('inpUrl').value = l.url; $('inpTitle').value = l.title; $('inpTrailer').value = l.trailer || ''; $('inpThumb').value = l.thumbnail || ''; $('inpNote').value = l.note || ''; $('aiStatus').textContent = '';
  populateCatSelect(l.cat); updatePlatformField(); $('overlay').classList.add('open');
}
function closeModal(){ $('overlay').classList.remove('open'); }
function populateCatSelect(selected){ $('inpCat').innerHTML = cats.map(c => `<option value="${escapeHtml(c)}" ${c===selected?'selected':''}>${escapeHtml(c)}</option>`).join(''); }
function updatePlatformField(){ const p = detectPlatform($('inpUrl').value); $('inpPlatform').value = p.label; }

async function saveLinkFromForm(){
  const url = normalizeUrl($('inpUrl').value);
  let title = $('inpTitle').value.trim();
  const cat = $('inpCat').value || 'أخرى';
  const trailer = normalizeUrl($('inpTrailer').value);
  const note = $('inpNote').value.trim();
  const thumbnail = normalizeUrl($('inpThumb').value);
  const platform = detectPlatform(url).label;

  if(!url){ toast('⚠️ الرابط مطلوب'); return; }
  if(!/^https?:\/\//i.test(url)){ toast('⚠️ الرابط لازم يبدأ بـ http أو https'); return; }
  if(!title){
    title = fallbackTitleFor(url, '', note);
    $('inpTitle').value = title;
  }

  let cloudItem = null;
  if(editId){
    const idx = links.findIndex(x => x.id === editId);
    if(idx !== -1){
      links[idx] = { ...links[idx], url, title, cat, trailer, note, thumbnail, platform, updatedAt: nowIso() };
      cloudItem = links[idx];
    }
    toast('✅ تم التعديل');
  } else {
    const existing = links.find(l => canonicalUrl(l.url) === canonicalUrl(url));
    if(existing){
      existing.title = title || existing.title;
      existing.cat = cat || existing.cat;
      existing.trailer = trailer || existing.trailer || '';
      existing.note = note || existing.note || '';
      existing.thumbnail = thumbnail || existing.thumbnail || '';
      existing.platform = platform;
      existing.updatedAt = nowIso();
      cloudItem = existing;
      toast('ℹ️ الرابط كان محفوظ، وتم تحديثه');
    }else{
      if(!canAddLink()) return;
      cloudItem = { id: uid(), url, title, cat, trailer, note, thumbnail, platform, favorite:false, ts: Date.now(), updatedAt: nowIso() };
      links.unshift(cloudItem);
      toast('✅ تم الحفظ');
    }
  }

  currentCat = 'all';
  saveLocal();
  closeModal();
  renderTabs();
  renderList();
  if(cloudItem) upsertLinkCloud(cloudItem).catch(e => console.warn('Cloud upsert failed after local save', e));
}
async function deleteLink(id){
  if(!confirm('حذف هذا الرابط؟')) return;
  links = links.filter(x => x.id !== id); saveLocal(); await deleteLinkCloud(id); renderList(); toast('تم الحذف');
}
async function deleteLinksCloud(ids){ if(!sbClient || !cloudUser || !ids.length) return; const { error } = await sbClient.from('links').delete().in('id', ids); if(error) console.warn(error); }
async function deleteAllLinksCloud(){ if(!sbClient || !cloudUser) return; const { error } = await sbClient.from('links').delete().eq('user_id', cloudUser.id); if(error) console.warn(error); }
async function deleteSelectedLinks(){ const ids = [...selectedIds]; if(!ids.length){ toast('اختر رابطًا واحدًا على الأقل'); return; } if(!confirm(`حذف ${ids.length} رابط محدد؟ لا يمكن التراجع.`)) return; links = links.filter(l => !selectedIds.has(l.id)); saveLocal(); await deleteLinksCloud(ids); selectedIds.clear(); renderTabs(); renderList(); toast(`تم حذف ${ids.length} رابط`); }
async function deleteAllLinks(){ if(!links.length){ toast('لا توجد روابط للحذف'); return; } if(!confirm(`مسح جميع الروابط وعددها ${links.length}؟\nلا يمكن التراجع عن هذه العملية.`)) return; links = []; selectedIds.clear(); saveLocal(); await deleteAllLinksCloud(); setSelectionMode(false); renderTabs(); renderList(); toast('تم مسح جميع الروابط'); }
function selectVisibleLinks(){ getVisibleLinks().forEach(l => selectedIds.add(l.id)); updateSelectionUi(); renderList(); }
function clearSelectedLinks(){ selectedIds.clear(); updateSelectionUi(); renderList(); }
function backupPayload(){ return { app:'LinkVault', format:'linkvault-backup', version:1, exportedAt:nowIso(), categories:[...cats], links:normalizeLinks(links), preferences:{ theme:currentTheme, viewMode } }; }
function backupFilename(){ return `LinkVault-backup-${new Date().toISOString().slice(0,10)}.json`; }
async function exportBackup(){
  try{
    const content = JSON.stringify(backupPayload(), null, 2);
    const file = new File([content], backupFilename(), { type:'application/json' });
    if(navigator.share && (!navigator.canShare || navigator.canShare({ files:[file] }))){
      try{ await navigator.share({ title:'نسخة LinkVault الاحتياطية', files:[file] }); toast('✅ تم تجهيز النسخة الاحتياطية'); return; }catch(e){ if(String(e?.name || '') === 'AbortError') return; }
    }
    const blobUrl = URL.createObjectURL(file); const a = document.createElement('a'); a.href = blobUrl; a.download = file.name; document.body.appendChild(a); a.click(); a.remove(); setTimeout(()=>URL.revokeObjectURL(blobUrl), 1500); toast('✅ تم حفظ النسخة الاحتياطية');
  }catch(e){ console.warn(e); toast('⚠️ تعذر إنشاء النسخة الاحتياطية'); }
}
function beginRestore(){ $('restoreFileInput').value=''; $('restoreFileInput').click(); }
function validateBackup(data){ if(!data || typeof data !== 'object' || !Array.isArray(data.links)) throw new Error('ملف غير صالح'); const restoredLinks = normalizeLinks(data.links); const restoredCats = Array.isArray(data.categories) ? data.categories.map(x=>String(x||'').trim()).filter(Boolean) : []; return { links:restoredLinks, categories:[...new Set(restoredCats.length ? restoredCats : restoredLinks.map(l=>l.cat).filter(Boolean))], preferences:data.preferences || {} }; }
function showRestoreChoice(data){ pendingRestoreData = data; $('restoreSummary').textContent = `الملف يحتوي على ${data.links.length} رابط و${data.categories.length} تصنيف. سيتم دمج النسخة مع روابط الحساب الحالية وحفظ الجميع دون حذف أو استبدال.`; $('restoreOverlay').classList.add('open'); }
function closeRestoreChoice(){ pendingRestoreData = null; $('restoreOverlay').classList.remove('open'); }
async function replaceCloudFromLocal(){ if(!sbClient || !cloudUser) return; await sbClient.from('links').delete().eq('user_id', cloudUser.id); await sbClient.from('categories').delete().eq('user_id', cloudUser.id); for(const c of cats) await upsertCategoryCloud(c); for(const l of links) await upsertLinkCloud(l); }
async function applyRestore(mode){
  if(!pendingRestoreData) return;
  const data=pendingRestoreData; closeRestoreChoice();
  const byUrl=new Map(links.map(l=>[canonicalUrl(l.url),l]));
  for(const source of normalizeLinks(data.links)){
    const key=canonicalUrl(source.url), existing=byUrl.get(key);
    if(existing){ existing.title=existing.title||source.title; existing.note=existing.note||source.note; existing.thumbnail=existing.thumbnail||source.thumbnail; existing.trailer=existing.trailer||source.trailer; existing.cat=existing.cat||source.cat; existing.updatedAt=nowIso(); }
    else { const incoming={...source,id:uid(),updatedAt:nowIso()}; links.push(incoming); byUrl.set(key,incoming); }
  }
  cats=normalizeCategories([...cats,...data.categories,...links.map(l=>l.cat).filter(Boolean)]); currentCat='all'; selectedIds.clear(); saveLocal(); renderTabs(); renderList();
  try{ if(cloudUser){ updateSettingsStatus('جاري رفع النسخة الاحتياطية إلى الحساب...', 'warning-text'); for(const c of cats) await upsertCategoryCloud(c); for(const l of links) await upsertLinkCloud(l); await loadCloudData(); updateSettingsStatus('✅ تم دمج النسخة وحفظها على الحساب', 'success-text'); } toast('✅ تم دمج النسخة الاحتياطية وحفظها'); }
  catch(e){ showCloudError(e); toast('⚠️ تم الدمج محليًا وتعذر رفعه الآن؛ اضغط مزامنة لاحقًا'); }
}
async function shareLink(link){
  try{
    if(navigator.share){
      await navigator.share({ title: link.title || 'LinkVault', text: link.note || link.title || link.url, url: link.url });
      toast('✅ تمت مشاركة الرابط');
      return;
    }
    if(navigator.clipboard && navigator.clipboard.writeText){
      await navigator.clipboard.writeText(link.url);
      toast('📋 تم نسخ الرابط. الصقه في التطبيق الذي تريد مشاركته.');
      return;
    }
  }catch(e){ if(String(e && e.name || '') === 'AbortError') return; }
  prompt('انسخ هذا الرابط للمشاركة', link.url);
}

function openCatModal(){
  $('inpNewCat').value = ''; renderCatList(); $('catOverlay').classList.add('open'); setTimeout(()=>$('inpNewCat').focus(), 100);
}
function isProtectedCategory(name){ return name === OTHER_CAT; }
function canRenameCategory(oldName, newName){
  if(!isCommercialFree()) return true;
  const base = new Set(defaultCustomCategories());
  const oldWasCustom = oldName !== OTHER_CAT && !base.has(oldName);
  const newIsCustom = newName !== OTHER_CAT && !base.has(newName);
  const projected = customCategoriesCount() - (oldWasCustom ? 1 : 0) + (newIsCustom ? 1 : 0);
  if(projected <= PLAN_LIMITS.freeCustomCategories) return true;
  toast(`🔒 النسخة المجانية تسمح بـ ${PLAN_LIMITS.freeCustomCategories} أنواع إضافية فقط`);
  return false;
}
function renderCatList(){
  const movable = cats.filter(c=>c!==OTHER_CAT);
  $('catList').innerHTML = cats.map((c, idx) => {
    const isOther = c === OTHER_CAT;
    const moveIndex = movable.indexOf(c);
    const upDisabled = isOther || moveIndex <= 0;
    const downDisabled = isOther || moveIndex < 0 || moveIndex >= movable.length - 1;
    const suffix = isOther ? ' <small style="color:var(--muted)">(آخر القائمة)</small>' : '';
    return `<div class="cat-item"><span class="cat-item-name">${idx + 1}. ${escapeHtml(c)}${suffix}</span><div class="cat-item-actions"><button class="edit-btn" data-index="${idx}" data-action="rename" title="تعديل الاسم" ${isOther?'disabled':''}>تعديل</button><button class="move-btn" data-index="${idx}" data-action="move" data-dir="up" title="تحريك للأعلى" ${upDisabled?'disabled':''}>↑</button><button class="move-btn" data-index="${idx}" data-action="move" data-dir="down" title="تحريك للأسفل" ${downDisabled?'disabled':''}>↓</button><button class="del-btn" data-index="${idx}" data-action="delete" title="حذف النوع" ${isOther?'disabled':''}>حذف</button></div></div>`;
  }).join('');
  $('catList').querySelectorAll('button').forEach(btn => btn.addEventListener('click', async () => {
    const idx = Number(btn.dataset.index);
    const c = cats[idx];
    if(!c) return;
    if(btn.dataset.action === 'rename'){ await renameCategory(c); return; }
    if(btn.dataset.action === 'delete'){ await removeCategory(c); return; }
    if(btn.dataset.action === 'move') moveCategory(c, btn.dataset.dir);
  }));
}
async function addCategory(){
  const v = $('inpNewCat').value.trim();
  if(!v){ toast('⚠️ أدخل اسم النوع'); return; }
  if(v === OTHER_CAT){ toast('⚠️ هذا الخيار موجود مسبقًا'); return; }
  if(!cats.includes(v)){
    if(!canAddCustomCategory(v)) return;
    cats = normalizeCategories([...cats, v]);
    saveLocal();
    await upsertCategoryCloud(v);
  }
  $('inpNewCat').value='';
  $('catOverlay').classList.remove('open');
  renderTabs(); renderCatList(); toast(`✅ تمت إضافة ${v}`);
}
async function renameCategory(oldName){
  if(oldName === OTHER_CAT){ toast('⚠️ لا يمكن تعديل خيار أخرى'); return; }
  const nextName = String(prompt(`اكتب الاسم الجديد للنوع ${oldName}`, oldName) || '').trim();
  if(!nextName || nextName === oldName) return;
  if(nextName === OTHER_CAT){ toast('⚠️ اسم أخرى محجوز'); return; }
  if(cats.includes(nextName)){ toast('⚠️ هذا النوع موجود مسبقًا'); return; }
  if(!canRenameCategory(oldName, nextName)) return;
  const affected = links.filter(l=>l.cat === oldName);
  const wasProtected = protectedCats.has(oldName);
  cats = normalizeCategories(cats.map(c=>c===oldName ? nextName : c));
  affected.forEach(l=>{ l.cat = nextName; l.updatedAt = nowIso(); });
  if(currentCat === oldName) currentCat = nextName;
  if(wasProtected){ protectedCats.delete(oldName); protectedCats.add(nextName); }
  saveLocal();
  try{
    await deleteCategoryCloud(oldName);
    await upsertCategoryCloud(nextName);
    for(const link of affected) await upsertLinkCloud(link);
  }catch(e){ console.warn('Category rename cloud sync failed', e); }
  renderTabs(); renderCatList(); renderList(); toast(`✅ تم تعديل النوع إلى ${nextName}`);
}
async function removeCategory(name){
  if(name === OTHER_CAT){ toast('⚠️ لا يمكن حذف خيار أخرى لأنه يستقبل روابط الأنواع المحذوفة'); return; }
  const affected = links.filter(l=>l.cat === name);
  const msg = affected.length ? `النوع ${name} يحتوي على ${affected.length} رابط. سيتم نقلها إلى أخرى ثم حذف النوع. متابعة؟` : `حذف النوع ${name}؟`;
  if(!confirm(msg)) return;
  affected.forEach(l=>{ l.cat = OTHER_CAT; l.updatedAt = nowIso(); });
  cats = normalizeCategories(cats.filter(c=>c!==name));
  protectedCats.delete(name);
  if(currentCat === name) currentCat = 'all';
  saveLocal();
  try{
    await deleteCategoryCloud(name);
    for(const link of affected) await upsertLinkCloud(link);
  }catch(e){ console.warn('Category delete cloud sync failed', e); }
  renderTabs(); renderCatList(); renderList(); toast(affected.length ? '✅ تم حذف النوع ونقل روابطه إلى أخرى' : '✅ تم حذف النوع');
}
function moveCategory(cat, dir){
  if(cat === OTHER_CAT) return;
  const copy = cats.filter(c=>c!==OTHER_CAT);
  const currentIndex = copy.indexOf(cat);
  if(currentIndex < 0) return;
  const target = dir === 'up' ? currentIndex - 1 : currentIndex + 1;
  if(target < 0 || target >= copy.length) return;
  const [item] = copy.splice(currentIndex, 1);
  copy.splice(target, 0, item);
  cats = normalizeCategories(copy);
  saveLocal(); renderTabs(); renderCatList(); renderList(); toast('✅ تم تحديث ترتيب الأنواع');
}


async function fetchMetadata(){
  const url = normalizeUrl($('inpUrl').value); if(!url){ toast('⚠️ أدخل الرابط أولاً'); return; }
  $('inpUrl').value = url; updatePlatformField();
  const btn = $('btnFetch'); const status = $('aiStatus'); btn.disabled = true; btn.innerHTML = '<span class="spinner"></span> جاري الجلب...'; status.textContent = '';
  try{
    const data = await getMetadata(url);
    if(data.title && !$('inpTitle').value.trim()) $('inpTitle').value = data.title;
    if(data.image && !$('inpThumb').value.trim()) $('inpThumb').value = data.image;
    status.textContent = data.title ? '✅ تم جلب العنوان والصورة' : 'ℹ️ لم أجد عنوان واضح، اكتب العنوان يدويًا';
  }catch(e){ status.textContent = '⚠️ تعذر الجلب. لو الرابط من إنستغرام/تيك توك/فيسبوك اكتب العنوان يدويًا.'; }
  btn.disabled = false; btn.innerHTML = '✨ جلب العنوان والصورة';
}
async function getMetadata(url){
  const cfg = getSettings();
  if(cfg.BACKEND_URL){
    const res = await fetch(`${cfg.BACKEND_URL.replace(/\/$/,'')}/api/metadata?url=${encodeURIComponent(url)}`);
    if(res.ok) return await res.json();
  }
  const p = detectPlatform(url);
  if(p.id === 'youtube'){
    const res = await fetch(`https://www.youtube.com/oembed?url=${encodeURIComponent(url)}&format=json`);
    if(res.ok){ const d = await res.json(); return { title:d.title || '', image:d.thumbnail_url || '', author:d.author_name || '', platform:'YouTube' }; }
  }
  return { title:'', image:'', platform:p.label };
}
async function fetchTrailer(){
  const title = $('inpTitle').value.trim(); if(!title){ toast('⚠️ أدخل العنوان أولاً'); return; }
  const btn = $('btnTrailer'); const old = btn.innerHTML; btn.disabled = true; btn.innerHTML = '<span class="spinner"></span> جاري البحث...';
  try{
    const cfg = getSettings();
    if(cfg.BACKEND_URL){
      const res = await fetch(`${cfg.BACKEND_URL.replace(/\/$/,'')}/api/trailer?title=${encodeURIComponent(title)}`);
      if(res.ok){ const d = await res.json(); if(d.trailerUrl){ $('inpTrailer').value = d.trailerUrl; toast('✅ تم جلب التريلر'); } else if(d.searchUrl){ window.open(d.searchUrl, '_blank'); toast('🎬 افتح النتيجة المناسبة وانسخ الرابط'); } }
    } else {
      window.open(`https://www.youtube.com/results?search_query=${encodeURIComponent(title + ' trailer official الإعلان الرسمي')}`, '_blank'); toast('🎬 افتح الفيديو المناسب وانسخ رابطه هنا');
    }
  }catch(e){ window.open(`https://www.youtube.com/results?search_query=${encodeURIComponent(title + ' trailer official')}`, '_blank'); }
  btn.disabled = false; btn.innerHTML = old;
}

function authProviderName(user){
  const provider = String(user?.app_metadata?.provider || user?.app_metadata?.providers?.[0] || user?.identities?.[0]?.provider || 'email').toLowerCase();
  if(provider === 'apple') return 'Apple ID';
  if(provider === 'google') return 'Google';
  return currentLanguage === 'en' ? 'Email' : 'البريد الإلكتروني';
}
function resetOtpControls(){
  clearInterval(otpCooldownTimer); otpCooldownTimer = null;
  const send = $('btnSendOtp');
  const resend = $('btnResendOtp');
  if(send){ send.disabled = false; send.textContent = currentLanguage === 'en' ? 'Send verification code' : 'إرسال رمز التحقق'; }
  if(resend){ resend.disabled = false; resend.textContent = currentLanguage === 'en' ? 'Resend code' : 'إعادة إرسال الرمز'; }
}
function renderAuthUI(){
  const loggedIn = !!cloudUser;
  const signedOutPanel = $('authSignedOutPanel');
  const signedInPanel = $('authSignedInPanel');
  const actions = $('accountActions');
  if(signedOutPanel) signedOutPanel.hidden = loggedIn;
  if(signedInPanel) signedInPanel.hidden = !loggedIn;
  if(actions) actions.hidden = !loggedIn;
  const box = $('authBox');
  if(box) box.classList.toggle('signed-in', loggedIn);

  if(loggedIn){
    pendingOtpEmail = ''; STORE.remove(LS_PENDING_OTP);
    if($('authOtp')) $('authOtp').value = '';
    setOtpPanelVisible(false);
    resetOtpControls();
    const identity = cloudUser.email || cloudUser.user_metadata?.email || cloudUser.user_metadata?.full_name || cloudUser.id || '';
    const provider = authProviderName(cloudUser);
    if($('authSignedInTitle')) $('authSignedInTitle').textContent = currentLanguage === 'en' ? 'Signed in' : 'تم تسجيل الدخول';
    if($('authSignedInIdentity')) $('authSignedInIdentity').textContent = identity;
    if($('authSignedInProvider')) $('authSignedInProvider').textContent = currentLanguage === 'en' ? `Signed in with ${provider}` : `تسجيل الدخول بواسطة ${provider}`;
  }else{
    if($('authSignedInIdentity')) $('authSignedInIdentity').textContent = '';
    if($('authSignedInProvider')) $('authSignedInProvider').textContent = '';
  }
}

function updateCloudStatus(kind='local', text='محلي'){
  const el = $('cloudStatus'); el.className = 'status-pill'; if(kind === 'online') el.classList.add('online'); if(kind === 'warn') el.classList.add('warn'); el.querySelector('span:last-child').textContent = text;
}
function updateSettingsStatus(msg, cls=''){
  $('settingsStatus').className = 'settings-status' + (cls ? ' ' + cls : ''); $('settingsStatus').textContent = msg;
}
async function initSupabase(){
  const cfg = getSettings();
  if(!cfg.SUPABASE_URL || !cfg.SUPABASE_ANON_KEY || !window.supabase){ cloudUser = null; renderAuthUI(); updateCloudStatus('local','محلي'); updateSettingsStatus('الوضع الحالي: حفظ محلي على الجهاز.'); return; }
  try{
    sbClient = window.supabase.createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY, { auth:{ persistSession:true, autoRefreshToken:true, detectSessionInUrl:false, flowType:'pkce' } });
    const { data } = await sbClient.auth.getUser(); cloudUser = data.user || null; if(cloudUser) activateCloudAccount(cloudUser); renderAuthUI(); if(cloudUser) identifyRevenueCatUser(cloudUser.id).catch(()=>{});
    if(cloudUser){ updateCloudStatus('online','مزامن'); updateSettingsStatus(`مسجل دخول: ${cloudUser.email || cloudUser.id}`, 'success-text'); await loadCloudData(); }
    else { updateCloudStatus('warn','غير مسجل'); updateSettingsStatus('استخدم رمز البريد أو Apple أو Google لتفعيل المزامنة.', 'warning-text'); }
    sbClient.auth.onAuthStateChange((event, session) => {
      cloudUser = session?.user || null;
      if(cloudUser) activateCloudAccount(cloudUser);
      renderAuthUI();
      if(cloudUser){
        identifyRevenueCatUser(cloudUser.id).catch(()=>{});
        updateCloudStatus('online','مزامن');
        updateSettingsStatus(`مسجل دخول: ${cloudUser.email || cloudUser.id}`, 'success-text');
        setTimeout(() => { synchronizeSignedInAccount(event).catch(showCloudError); }, 0);
      }else{
        updateCloudStatus('warn','غير مسجل');
        if(event === 'SIGNED_OUT') updateSettingsStatus('تم تسجيل الخروج. الروابط المحلية باقية على هذا الجهاز.');
      }
    });
    if(pendingAuthCallbackUrl){ const url = pendingAuthCallbackUrl; pendingAuthCallbackUrl = ''; await handleAuthCallbackUrl(url); }
  }catch(e){ cloudUser = null; renderAuthUI(); updateCloudStatus('warn','خطأ'); updateSettingsStatus('تعذر الاتصال بخدمة المزامنة.', 'danger-text'); }
}
function showCloudError(error){ console.warn('LinkVault cloud sync failed', error); updateCloudStatus('warn','خطأ مزامنة'); updateSettingsStatus('تعذر حفظ الروابط على الحساب: ' + (error?.message || error), 'danger-text'); }
function linkToRow(l){ const title=String(l.title||'').trim()||(()=>{try{return new URL(l.url).hostname;}catch(e){return 'رابط محفوظ';}})(); return { id:l.id, user_id:cloudUser?.id, title, url:l.url, platform:l.platform || detectPlatform(l.url).label, category_name:l.cat, notes:l.note || '', trailer_url:l.trailer || '', thumbnail_url:l.thumbnail || '', is_favorite:!!l.favorite, created_at:new Date(l.ts || Date.now()).toISOString(), updated_at:l.updatedAt || nowIso() }; }
function rowToLink(r){ return { id:r.id, title:r.title || '', url:r.url || '', cat:r.category_name || 'أخرى', note:r.notes || '', trailer:r.trailer_url || '', thumbnail:r.thumbnail_url || '', platform:r.platform || detectPlatform(r.url || '').label, favorite:!!r.is_favorite, ts:r.created_at ? new Date(r.created_at).getTime() : Date.now(), updatedAt:r.updated_at || nowIso() }; }
async function loadCloudData(){
  if(!sbClient || !cloudUser || syncing) return; syncing = true;
  try{
    const [cr, lr] = await Promise.all([ sbClient.from('categories').select('name').eq('user_id',cloudUser.id).order('created_at',{ascending:true}), sbClient.from('links').select('*').eq('user_id',cloudUser.id).order('created_at',{ascending:false}) ]);
    if(cr.error || lr.error) throw (cr.error || lr.error);
    if((cr.data || []).length){ cats = cr.data.map(x => x.name).filter(Boolean); }
    else { for(const c of cats) await upsertCategoryCloud(c); }
    const cloudLinks = (lr.data || []).map(rowToLink);
    const cloudByUrl = new Map(cloudLinks.map(x => [canonicalUrl(x.url), x]));
    const localLinks = links || [];
    for(const local of localLinks){
      const key = canonicalUrl(local.url);
      if(!cloudByUrl.has(key) && cloudUser){
        if(await upsertLinkCloud(local)){
          cloudLinks.push(local);
          cloudByUrl.set(key, local);
        }
      }
    }
    links = cloudLinks;
    const upgraded = upgradeExistingOtherCategories();
    saveLocal(); renderTabs(); renderList(); updateCloudStatus('online','مزامن');
    if(upgraded) links.forEach(l => upsertLinkCloud(l).catch(()=>{}));
  }catch(e){ updateCloudStatus('warn','خطأ'); updateSettingsStatus('تعذر تحميل بيانات المزامنة. حاول مرة أخرى لاحقًا.', 'danger-text'); }
  syncing = false;
}
async function upsertLinkCloud(l){ if(!sbClient || !cloudUser) return false; const row=linkToRow(l); let {error}=await sbClient.from('links').upsert(row,{onConflict:'id'}); if(error && /is_favorite.*schema cache|column.*is_favorite/i.test(error.message||'')){ delete row.is_favorite; ({error}=await sbClient.from('links').upsert(row,{onConflict:'id'})); } if(error && /row-level security|violates.*policy/i.test(error.message||'')){ l.id=uid(); row.id=l.id; ({error}=await sbClient.from('links').upsert(row,{onConflict:'id'})); if(!error) saveLocal(); } if(error) throw error; return true; }
async function deleteLinkCloud(id){ if(!sbClient || !cloudUser) return; const {error}=await sbClient.from('links').delete().eq('user_id',cloudUser.id).eq('id',id); if(error) throw error; }
async function upsertCategoryCloud(name){ if(!sbClient || !cloudUser) return; const {error}=await sbClient.from('categories').upsert({user_id:cloudUser.id,name},{onConflict:'user_id,name'}); if(error) throw error; }
async function deleteCategoryCloud(name){ if(!sbClient || !cloudUser) return; const {error}=await sbClient.from('categories').delete().eq('user_id',cloudUser.id).eq('name',name); if(error) throw error; }
async function synchronizeSignedInAccount(event='SIGNED_IN'){ if(authSyncPromise) return authSyncPromise; authSyncPromise=event==='SIGNED_IN'?syncLocalToCloud():loadCloudData(); try{await authSyncPromise;}finally{authSyncPromise=null;} }
async function syncLocalToCloud(){
  if(!sbClient || !cloudUser){ toast('⚠️ سجل دخول أولاً'); return; }
  updateSettingsStatus('جاري رفع البيانات المحلية...', 'warning-text');
  for(const c of cats) await upsertCategoryCloud(c);
  for(const l of links) await upsertLinkCloud(l);
  await loadCloudData(); updateSettingsStatus('✅ تمت المزامنة بنجاح', 'success-text'); toast('✅ تمت المزامنة');
}
function isNativeApp(){ try{return !!(window.Capacitor && typeof window.Capacitor.isNativePlatform === 'function' && window.Capacitor.isNativePlatform());}catch(e){return false;} }
function getAuthRedirectUrl(){ return isNativeApp() ? AUTH_REDIRECT_URL : ((window.location.origin || '') + (window.location.pathname || '/')); }
function normalizeOtp(value){
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  return String(value || '').replace(/[٠-٩]/g, d => arabic.indexOf(d)).replace(/[۰-۹]/g, d => persian.indexOf(d)).replace(/\D/g,'').slice(0,6);
}
function setOtpPanelVisible(show){
  const panel = $('otpPanel');
  if(panel) panel.hidden = !show;
  if(show && $('authOtp')) setTimeout(() => $('authOtp').focus(), 120);
}
function startOtpCooldown(seconds=60){
  clearInterval(otpCooldownTimer);
  let left = seconds;
  const send = $('btnSendOtp');
  const resend = $('btnResendOtp');
  const refresh = () => {
    const disabled = left > 0;
    if(send){ send.disabled = disabled; send.textContent = disabled ? `إعادة الإرسال بعد ${left}ث` : 'إرسال رمز التحقق'; }
    if(resend){ resend.disabled = disabled; resend.textContent = disabled ? `إعادة الإرسال بعد ${left}ث` : 'إعادة إرسال الرمز'; }
    if(left <= 0){ clearInterval(otpCooldownTimer); otpCooldownTimer = null; }
    left -= 1;
  };
  refresh();
  otpCooldownTimer = setInterval(refresh, 1000);
}
async function ensureAuthClient(){
  if(!sbClient) await initSupabase();
  if(!sbClient){ toast('⚠️ خدمة الحساب غير متاحة حاليًا'); return false; }
  return true;
}
async function sendEmailOtp(){
  const button = $('btnSendOtp');
  try{
    if(!await ensureAuthClient()) return;
    const email = $('authEmail').value.trim().toLowerCase();
    if(!/^\S+@\S+\.\S+$/.test(email)){ toast('⚠️ أدخل بريدًا إلكترونيًا صحيحًا'); return; }
    button.disabled = true; button.textContent = 'جاري إرسال الرمز...';
    const { error } = await sbClient.auth.signInWithOtp({ email, options:{ shouldCreateUser:true, emailRedirectTo:getAuthRedirectUrl() } });
    if(error) throw error;
    pendingOtpEmail = email; STORE.set(LS_PENDING_OTP, email); setOtpPanelVisible(true); startOtpCooldown(60);
    updateSettingsStatus(`📧 أرسلنا رمز تحقق إلى ${email}`, 'success-text'); toast('📧 تم إرسال رمز التحقق');
  }catch(e){
    const msg = e?.message || 'تعذر إرسال رمز التحقق';
    updateSettingsStatus(msg, 'danger-text'); toast(msg);
    button.disabled = false; button.textContent = 'إرسال رمز التحقق';
  }
}
async function verifyEmailOtp(){
  const button = $('btnVerifyOtp');
  try{
    if(!await ensureAuthClient()) return;
    const email = (pendingOtpEmail || $('authEmail').value).trim().toLowerCase();
    const token = normalizeOtp($('authOtp').value);
    $('authOtp').value = token;
    if(!email || token.length !== 6){ toast('⚠️ أدخل رمز التحقق المكوّن من 6 أرقام'); return; }
    button.disabled = true; button.textContent = 'جاري التحقق...';
    const { data, error } = await sbClient.auth.verifyOtp({ email, token, type:'email' });
    if(error) throw error;
    cloudUser = data.user || data.session?.user || null; if(cloudUser) activateCloudAccount(cloudUser); renderAuthUI(); if(cloudUser) identifyRevenueCatUser(cloudUser.id).catch(()=>{});
    pendingOtpEmail = ''; STORE.remove(LS_PENDING_OTP); $('authOtp').value = ''; setOtpPanelVisible(false);
    updateCloudStatus(cloudUser ? 'online' : 'warn', cloudUser ? 'مزامن' : 'غير مسجل');
    updateSettingsStatus('✅ تم التحقق وتسجيل الدخول بنجاح.', 'success-text'); toast('✅ تم تسجيل الدخول'); if(cloudUser) await synchronizeSignedInAccount('SIGNED_IN');
  }catch(e){
    const msg = e?.message || 'رمز التحقق غير صحيح أو انتهت صلاحيته';
    updateSettingsStatus(msg, 'danger-text'); toast('⚠️ ' + msg);
  }finally{
    button.disabled = false; button.textContent = 'تأكيد';
  }
}
async function openAuthBrowser(url){
  if(!url) throw new Error('لم يتم إنشاء رابط تسجيل الدخول');
  if(isNativeApp()){
    const Browser = getNativePlugin('Browser');
    if(Browser?.open){ await Browser.open({ url, presentationStyle:'fullscreen', toolbarColor:'#0d0d14' }); return; }
  }
  window.location.assign(url);
}
async function closeAuthBrowser(){
  if(!isNativeApp()) return;
  try{ const Browser = getNativePlugin('Browser'); if(Browser?.close) await Browser.close(); }catch(e){}
}
async function signInWithOAuthProvider(provider){
  const label = provider === 'apple' ? 'Apple' : 'Google';
  try{
    if(!await ensureAuthClient()) return;
    updateSettingsStatus(`جاري فتح تسجيل الدخول بواسطة ${label}...`, 'warning-text');
    const queryParams = provider === 'google' ? { prompt:'select_account' } : undefined;
    const { data, error } = await sbClient.auth.signInWithOAuth({ provider, options:{ redirectTo:getAuthRedirectUrl(), skipBrowserRedirect:isNativeApp(), queryParams } });
    if(error) throw error;
    if(data?.url) await openAuthBrowser(data.url);
  }catch(e){
    const msg = e?.message || `تعذر تسجيل الدخول بواسطة ${label}`;
    updateSettingsStatus(msg, 'danger-text'); toast(msg);
  }
}
async function logout(){
  if(cloudUser?.id) persistAccountData(cloudUser.id);
  if(sbClient) await sbClient.auth.signOut();
  await logoutRevenueCatUser();
  await closeAuthBrowser();
  cloudUser = null; activateGuestAccount(); pendingOtpEmail = ''; STORE.remove(LS_PENDING_OTP); setOtpPanelVisible(false); resetOtpControls(); if($('authEmail')) $('authEmail').value = ''; if($('authOtp')) $('authOtp').value = ''; renderAuthUI();
  updateCloudStatus('warn','غير مسجل'); updateSettingsStatus('تم تسجيل الخروج. الروابط المحلية باقية على هذا الجهاز.'); toast('تم تسجيل الخروج');
}

function openSettings(){ applyTheme(currentTheme, false); updateProUi(); renderAuthUI(); $('settingsOverlay').classList.add('open'); if(APP_EDITION === 'commercial' && rcReady) refreshRevenueCatStatus(); }
function closeSettings(){ $('settingsOverlay').classList.remove('open'); }

let lastIncomingShareSignature = '';
let lastIncomingShareAt = 0;
function handleIncomingShareFromParams(params){
  const rawUrl = params.get('url') || extractFirstUrl(params.get('text')) || '';
  const title = params.get('title') || '';
  const text = params.get('text') || '';
  const source = params.get('source') || '';
  const sharedUrl = normalizeUrl(rawUrl || extractFirstUrl(text));
  if(sharedUrl){
    const signature = `${sharedUrl}|${title}|${text.slice(0, 120)}|${source}`;
    const now = Date.now();
    if(signature === lastIncomingShareSignature && now - lastIncomingShareAt < 8000) return true;
    lastIncomingShareSignature = signature;
    lastIncomingShareAt = now;

    if(source === 'share_extension' || params.get('autosave') === '1'){
      const pendingTs = Number(params.get('ts') || 0);
      saveSharedLinkDirectly({ url: sharedUrl, title, text, note: params.get('note') || '', cat: params.get('cat') || '' }).then(saved => {
        if(saved && pendingTs > 0) clearPendingNativeShare(pendingTs);
      });
    }else{
      setTimeout(() => openAddModal({ url:sharedUrl, title: title && title !== sharedUrl ? title : '', note: params.get('note') || '', cat: params.get('cat') || '' }), 280);
    }
    return true;
  }
  return false;
}
function checkShareTarget(){
  const params = new URLSearchParams(window.location.search);
  if(params.get('action') === 'add') setTimeout(() => openAddModal(), 150);
  const handled = handleIncomingShareFromParams(params);
  if(handled || params.get('action')) window.history.replaceState({}, '', window.location.pathname || './');
}
function isLinkVaultDeepLink(u){ return u && (u.protocol === 'linkvaultq8:' || u.protocol === 'linkvault:'); }
function isAuthCallbackUrl(u){ return isLinkVaultDeepLink(u) && (u.hostname === 'auth-callback' || u.pathname.replace(/^\//,'') === 'auth-callback'); }
function authParamsFromUrl(raw){ const u = new URL(raw); const params = new URLSearchParams(u.search); const hash = new URLSearchParams((u.hash || '').replace(/^#/,'?')); for(const [k,v] of hash.entries()) if(!params.has(k)) params.set(k,v); return params; }
async function handleAuthCallbackUrl(raw){
  if(!sbClient){ pendingAuthCallbackUrl = raw; return false; }
  try{
    await closeAuthBrowser();
    const params = authParamsFromUrl(raw); const errorText = params.get('error_description') || params.get('error'); if(errorText) throw new Error(decodeURIComponent(errorText.replace(/\+/g,' ')));
    const code = params.get('code'); const access_token = params.get('access_token'); const refresh_token = params.get('refresh_token'); let result;
    if(code) result = await sbClient.auth.exchangeCodeForSession(code);
    else if(access_token && refresh_token) result = await sbClient.auth.setSession({ access_token, refresh_token });
    else { const current = await sbClient.auth.getSession(); if(current.data?.session) result = current; else throw new Error('رابط تسجيل الدخول لا يحتوي بيانات جلسة صالحة'); }
    if(result?.error) throw result.error; cloudUser = result?.data?.session?.user || (await sbClient.auth.getUser()).data?.user || null; if(cloudUser) activateCloudAccount(cloudUser); renderAuthUI(); if(cloudUser) identifyRevenueCatUser(cloudUser.id).catch(()=>{});
    updateCloudStatus(cloudUser ? 'online' : 'warn', cloudUser ? 'مزامن' : 'غير مسجل'); updateSettingsStatus('✅ تم تسجيل الدخول بنجاح.', 'success-text'); toast('✅ تم تسجيل الدخول'); if(cloudUser) await synchronizeSignedInAccount('SIGNED_IN'); if(!isNativeApp() && (window.location.search || window.location.hash)) window.history.replaceState({}, '', window.location.pathname || '/'); return true;
  }catch(e){ await closeAuthBrowser(); console.warn('Auth callback failed', e); updateSettingsStatus(`تعذر إكمال تسجيل الدخول: ${e?.message || e}`, 'danger-text'); toast('⚠️ تعذر إكمال تسجيل الدخول'); return false; }
}
function routeDeepLink(raw){ try{ const u = new URL(raw); if(!isLinkVaultDeepLink(u)) return false; if(isAuthCallbackUrl(u)){ handleAuthCallbackUrl(raw); return true; } return handleIncomingShareFromParams(u.searchParams); }catch(e){ return false; } }
function captureBrowserAuthCallback(){ try{ const params = authParamsFromUrl(window.location.href); if(params.get('code') || params.get('access_token') || params.get('error') || params.get('error_code')) pendingAuthCallbackUrl = window.location.href; }catch(e){} }
function initNativeDeepLinks(){
  const App = window.Capacitor?.Plugins?.App;
  if(!App) return;
  App.addListener('appUrlOpen', data => { if(data?.url) routeDeepLink(data.url); });
  if(App.getLaunchUrl){ App.getLaunchUrl().then(res => { if(res?.url) routeDeepLink(res.url); }).catch(()=>{}); }
}

async function clearPendingNativeShare(upToTimestamp){
  try{
    const PendingShare = getNativePlugin('PendingShare');
    if(!PendingShare || !PendingShare.clearPendingShare) return false;
    const value = Number(upToTimestamp);
    const options = Number.isFinite(value) && value > 0 ? { upToTimestamp:value } : {};
    await PendingShare.clearPendingShare(options);
    return true;
  }catch(e){
    console.warn('PendingShare clear failed', e);
    return false;
  }
}

function pendingShareBatch(res){
  if(!res || !res.hasShare) return [];
  if(Array.isArray(res.shares) && res.shares.length) return res.shares;
  return [{
    id:res.id || '',
    url:res.url || '',
    title:res.title || '',
    text:res.text || '',
    note:res.note || '',
    cat:res.cat || '',
    timestamp:Number(res.timestamp || 0)
  }];
}

let pendingShareConsumeInFlight = false;
async function consumePendingNativeShare(){
  if(pendingShareConsumeInFlight) return false;
  pendingShareConsumeInFlight = true;
  try{
    const PendingShare = getNativePlugin('PendingShare');
    if(!PendingShare || !PendingShare.getPendingShare) return false;
    const res = await PendingShare.getPendingShare();
    const shares = pendingShareBatch(res).sort((a,b) => Number(a.timestamp || 0) - Number(b.timestamp || 0));
    if(!shares.length) return false;

    let processed = 0;
    let clearedThrough = 0;
    for(const share of shares){
      const saved = await saveSharedLinkDirectly({
        url:share.url || '',
        title:share.title || '',
        text:share.text || '',
        note:share.note || '',
        cat:share.cat || share.category || ''
      });
      if(!saved) break;
      processed += 1;
      clearedThrough = Math.max(clearedThrough, Number(share.timestamp || 0));
    }

    if(processed > 0 && clearedThrough > 0){
      await clearPendingNativeShare(clearedThrough);
      if(processed > 1) toast(`✅ تم استيراد ${processed} روابط محفوظة`);
    }
    return processed > 0;
  }catch(e){
    console.warn('PendingShare consume failed', e);
    return false;
  }finally{
    pendingShareConsumeInFlight = false;
  }
}
function initPendingNativeShare(){
  const CapApp = window.Capacitor?.Plugins?.App;
  setTimeout(consumePendingNativeShare, 450);
  setTimeout(consumePendingNativeShare, 1400);
  if(CapApp && CapApp.addListener){
    CapApp.addListener('resume', () => { setTimeout(consumePendingNativeShare, 250); });
  }
}

async function runShareDiagnostics(){
  const report = [];
  try{
    const cap = window.Capacitor;
    const isNative = !!(cap && typeof cap.isNativePlatform === 'function' && cap.isNativePlatform());
    report.push('تطبيق آيفون أصلي (native): ' + (isNative ? 'نعم ✅' : 'لا ❌ (يبدو إنك بمتصفح ويب عادي)'));

    const plugin = getNativePlugin('PendingShare');
    report.push('إضافة PendingShare مسجلة بالتطبيق: ' + (plugin && plugin.getPendingShare ? 'نعم ✅' : 'لا ❌'));

    if(!plugin || !plugin.getPendingShare){
      report.push('السبب: PendingSharePlugin غير مسجل داخل Capacitor bridge. تأكد أن البناء الجديد شغّل scripts/add-ios-share-extension.rb وأن Main.storyboard صار يستخدم LinkVaultBridgeViewController.');
    } else {
      const res = await plugin.getPendingShare();
      const pending = pendingShareBatch(res);
      report.push('عدد الروابط المنتظرة في App Group: ' + pending.length);
      if(pending.length){
        const saved = await consumePendingNativeShare();
        report.push(saved ? `✅ تم استيراد الروابط المنتظرة داخل القائمة الآن.` : '⚠️ توجد بيانات مشاركة لكن تعذر استيرادها.');
      } else {
        report.push('يعني: الـ plugin شغال، لكن لا توجد روابط محفوظة في App Group حاليًا. جرّب مشاركة رابط جديد ثم افتح التطبيق.');
      }
    }
  }catch(e){
    report.push('⚠️ صار خطأ فعلي أثناء الفحص: ' + (e && e.message ? e.message : String(e)));
  }
  alert(report.join('\n\n'));
}

function toast(msg){ const el=$('toast'); el.textContent=msg; el.classList.add('show'); clearTimeout(toastTimer); toastTimer=setTimeout(()=>el.classList.remove('show'),2500); }
let deferredPrompt;
window.addEventListener('beforeinstallprompt', e => { e.preventDefault(); deferredPrompt = e; setTimeout(() => { if(document.querySelector('.install-bar')) return; const bar = document.createElement('div'); bar.className='install-bar'; bar.innerHTML = `<span>📲 ثبّت LinkVault كتطبيق</span><button id="doInstall">تثبيت</button><button class="close-install" id="closeInstall">✕</button>`; document.body.appendChild(bar); setTimeout(()=>bar.classList.add('show'),100); $('doInstall').addEventListener('click',()=>{ deferredPrompt.prompt(); deferredPrompt.userChoice.then(()=>bar.remove()); }); $('closeInstall').addEventListener('click',()=>bar.remove()); }, 3000); });

$('btnAdd').addEventListener('click', () => openAddModal());
$('btnQrScan').addEventListener('click', scanQrCode);
$('btnQrScanInline').addEventListener('click', scanQrCode);
$('btnSettings').addEventListener('click', openSettings);
$('btnCancel').addEventListener('click', closeModal);
$('overlay').addEventListener('click', e => { if(e.target === $('overlay')) closeModal(); });
$('btnSave').addEventListener('click', saveLinkFromForm);
$('inpUrl').addEventListener('input', updatePlatformField);
$('btnFetch').addEventListener('click', fetchMetadata);
$('btnTrailer').addEventListener('click', fetchTrailer);
$('searchInp').addEventListener('input', renderList);
$('btnClearSearch').addEventListener('click', () => { $('searchInp').value=''; renderList(); $('searchInp').focus(); });
$('btnCancelCat').addEventListener('click', () => $('catOverlay').classList.remove('open'));
$('btnConfirmCat').addEventListener('click', addCategory);
$('inpNewCat').addEventListener('keydown', e => { if(e.key === 'Enter') addCategory(); });
$('btnCloseSettings').addEventListener('click', closeSettings);
$('btnOpenPaywall').addEventListener('click', openPaywall);
$('btnRestorePurchases').addEventListener('click', restoreRevenueCatPurchases);
$('btnClosePaywall').addEventListener('click', closePaywall);
$('paywallOverlay').addEventListener('click', e => { if(e.target === $('paywallOverlay')) closePaywall(); });
document.querySelectorAll('[data-rc-package]').forEach(btn => btn.addEventListener('click', () => purchaseRevenueCatPackage(btn.dataset.rcPackage)));
$('btnPaywallRestore').addEventListener('click', restoreRevenueCatPurchases);
$('settingsOverlay').addEventListener('click', e => { if(e.target === $('settingsOverlay')) closeSettings(); });
$('btnSendOtp').addEventListener('click', sendEmailOtp);
$('btnVerifyOtp').addEventListener('click', verifyEmailOtp);
$('btnResendOtp').addEventListener('click', sendEmailOtp);
$('btnAppleLogin').addEventListener('click', () => signInWithOAuthProvider('apple'));
$('btnGoogleLogin').addEventListener('click', () => signInWithOAuthProvider('google'));
$('authOtp').addEventListener('input', e => { e.target.value = normalizeOtp(e.target.value); });
$('authOtp').addEventListener('keydown', e => { if(e.key === 'Enter') verifyEmailOtp(); });
$('authEmail').addEventListener('keydown', e => { if(e.key === 'Enter') sendEmailOtp(); });
$('btnLogout').addEventListener('click', logout);
$('btnSyncNow').addEventListener('click', syncLocalToCloud);
$('btnShareDiag').addEventListener('click', runShareDiagnostics);
$('btnSelectMode').addEventListener('click', () => setSelectionMode(!selectionMode));
document.querySelectorAll('[data-view]').forEach(btn => btn.addEventListener('click', () => setViewMode(btn.dataset.view)));
$('btnSelectVisible').addEventListener('click', selectVisibleLinks);
$('btnClearSelection').addEventListener('click', clearSelectedLinks);
$('btnDeleteSelected').addEventListener('click', deleteSelectedLinks);
$('btnDeleteAll').addEventListener('click', deleteAllLinks);
document.querySelectorAll('[data-theme]').forEach(btn => btn.addEventListener('click', () => applyTheme(btn.dataset.theme)));
$('languageSelect').addEventListener('change', e => { applyLanguageChoice(e.target.value, true); renderTabs(); renderList(); if($('catOverlay').classList.contains('open')) renderCatList(); translateTree(document.body, true); renderAuthUI(); });
$('btnBackup').addEventListener('click', exportBackup);
$('btnRestore').addEventListener('click', beginRestore);
$('restoreFileInput').addEventListener('change', async e => { const file=e.target.files?.[0]; if(!file) return; try{ showRestoreChoice(validateBackup(JSON.parse(await file.text()))); }catch(err){ toast('⚠️ ملف النسخة الاحتياطية غير صالح'); } });
$('btnRestoreMerge').addEventListener('click', () => applyRestore('merge'));
$('btnRestoreReplace').addEventListener('click', () => applyRestore('replace'));
$('btnRestoreCancel').addEventListener('click', closeRestoreChoice);
$('restoreOverlay').addEventListener('click', e => { if(e.target === $('restoreOverlay')) closeRestoreChoice(); });

applyTheme(currentTheme, false); initLanguage(); upgradeExistingOtherCategories(); saveLocal(); renderTabs(); renderList(); translateTree(document.body, true); renderAuthUI(); if(pendingOtpEmail){ $('authEmail').value = pendingOtpEmail; setOtpPanelVisible(true); } checkShareTarget(); captureBrowserAuthCallback(); initNativeDeepLinks(); initPendingNativeShare(); initSupabase(); initRevenueCat();
if('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js').catch(()=>{});
