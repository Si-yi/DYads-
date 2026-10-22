#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

/// DYKiller-style plugin backup actions used by the nested backup tools page.
void DYYYBackupExportSettings(UIViewController *presenter);
void DYYYBackupImportSettings(UIViewController *presenter);
void DYYYBackupUndoRestore(UIViewController *presenter);
void DYYYBackupResetSettings(UIViewController *presenter);

#ifdef __cplusplus
}
#endif
