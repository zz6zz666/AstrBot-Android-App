library global_repository;

export 'src/widgets/widgets.dart';
export 'src/foundation/constants.dart';
export 'src/foundation/global_assets.dart';
export 'src/utils/dimens.dart';
export 'src/widgets/wrap_list.dart';
export 'src/widgets/gesture.dart';
export 'package:signale/signale.dart';
export 'src/style/candy_colors.dart';
export 'package:permission_handler/permission_handler.dart';
export 'src/interface/process.dart';
export 'src/foundation/overlay_style.dart';
export 'src/pages/page.dart' hide CheckContainer;
export 'src/controller/tab_controller.dart';
export 'src/utils/assets_manager.dart';
export 'src/utils/utils.dart';
export 'src/extension/color_ext.dart';
export 'generated/intl/messages_all.dart';
import 'generated/intl/messages_en.dart' as en;
import 'generated/intl/messages_zh_CN.dart' as zh_CN;

Map<String, dynamic> enMessage = en.messages.messages;
Map<String, dynamic> zhCNMessage = zh_CN.messages.messages;
Map<String, dynamic> en_essage = en.messages.messages;
Map<String, dynamic> zh_cn_messages = zh_CN.messages.messages;
