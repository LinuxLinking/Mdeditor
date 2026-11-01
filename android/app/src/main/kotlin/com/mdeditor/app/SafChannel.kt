package com.mdeditor.app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class SafChannel(private val activity: Activity) {
    companion object {
        const val CHANNEL = "mdeditor/saf"
        const val REQ_OPEN = 0xA001
        const val REQ_SAVE = 0xA002
    }

    private var pendingResult: MethodChannel.Result? = null

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openDocument" -> {
                        pendingResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            // Android 14+:单一 type 严格匹配会过滤掉许多 .md 文件
                            // (有些文件管理器把 .md 注册为 text/plain 或 application/octet-stream)
                            // 改用 */* + EXTRA_MIME_TYPES 数组放宽过滤
                            type = "*/*"
                            val mimes = arrayOf(
                                "text/markdown",
                                "text/x-markdown",
                                "text/plain",
                                "application/octet-stream"
                            )
                            putExtra(Intent.EXTRA_MIME_TYPES, mimes)
                        }
                        activity.startActivityForResult(intent, REQ_OPEN)
                    }
                    "createDocument" -> {
                        // 修 0B 多文件根因:连点保存按钮会并发触发多次 createDocument,
                        // 每次 startActivityForResult 都启动一个 SAF Activity 并物化一个 0B
                        // 文件条目(Download provider 对同名加 (1)(2) 后缀)。pendingResult
                        // 是单实例,第二次会覆盖第一次的 result,且第二个 Activity 仍会物化
                        // 0B。这里在 Kotlin 侧加并发闸:前一个 save 还没返回时,直接拒绝
                        // 第二次,不启动新 Activity。
                        if (pendingResult != null) {
                            result.success(null)
                        } else {
                            pendingResult = result
                            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = call.argument<String>("mime") ?: "*/*"
                                putExtra(Intent.EXTRA_TITLE, call.argument<String>("suggestedName"))
                            }
                            activity.startActivityForResult(intent, REQ_SAVE)
                        }
                    }
                    "readUri" -> {
                        val uri = Uri.parse(call.argument<String>("uri"))
                        try {
                            // 显式 UTF-8 解码:默认 bufferedReader 用平台 charset,
                            // 在中文 Windows/旧 Android 上可能误判为 GBK 导致乱码
                            val text = activity.contentResolver.openInputStream(uri)?.use {
                                it.bufferedReader(Charsets.UTF_8).readText()
                            }
                            result.success(text)
                        } catch (e: Exception) {
                            result.error("READ_FAIL", e.message, null)
                        }
                    }
                    "writeUri" -> {
                        val uri = Uri.parse(call.argument<String>("uri"))
                        val bytes = call.argument<ByteArray>("bytes")!!
                        try {
                            activity.contentResolver.openOutputStream(uri, "wt")?.use {
                                it.write(bytes)
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("WRITE_FAIL", e.message, null)
                        }
                    }
                    "deleteDocument" -> {
                        val uri = Uri.parse(call.argument<String>("uri"))
                        try {
                            // 修导出:删除已 pick 的 SAF document 条目,
                            // 用于导出写入失败时清理 Download 里的 0B 残留文件。
                            val deleted = android.provider.DocumentsContract.deleteDocument(
                                activity.contentResolver, uri,
                            )
                            result.success(deleted)
                        } catch (e: Exception) {
                            result.error("DELETE_FAIL", e.message, null)
                        }
                    }
                    "deleteZeroSiblings" -> {
                        // 兜底清理:删除 Download 里同 basename 前缀的 0B 空壳文件。
                        // 即使并发闸漏网或 SAF provider 异常物化了多个条目,这里在保存
                        // 成功后扫描清理,保证用户看不到多余 0B。
                        val basename = call.argument<String>("basename") ?: ""
                        try {
                            val deleted = deleteZeroSiblings(basename)
                            result.success(deleted)
                        } catch (e: Exception) {
                            result.error("CLEANUP_FAIL", e.message, null)
                        }
                    }
                    "hasAllFilesAccess" -> {
                        // 检查 app 是否已获"所有文件访问权限"(MANAGE_EXTERNAL_STORAGE)。
                        // 授权后 app 才能用 File 清理 Download 里的 0B 空壳。
                        result.success(android.os.Environment.isExternalStorageManager())
                    }
                    "requestAllFilesAccess" -> {
                        // 引导用户到设置页授权"所有文件访问权限"。
                        if (android.os.Environment.isExternalStorageManager()) {
                            result.success(true)
                        } else {
                            try {
                                val intent = Intent(android.provider.Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                                    data = Uri.parse("package:${activity.packageName}")
                                }
                                activity.startActivity(intent)
                                result.success(false)
                            } catch (e: Exception) {
                                try {
                                    activity.startActivity(
                                        Intent(android.provider.Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                                    )
                                    result.success(false)
                                } catch (e2: Exception) {
                                    result.error("NO_ALL_FILES_SETTING", e2.message, null)
                                }
                            }
                        }
                    }
                    "queryName" -> {
                        // Phase 6 修复:之前 Dart 端 [SafColumn.name] 调本方法但
                        // Kotlin 端未实现,导致 MissingPluginException 抛出,
                        // _loadInitial 走 catch 丢弃已读文本 → 编辑器空白。
                        val uri = Uri.parse(call.argument<String>("uri"))
                        try {
                            val name = activity.contentResolver.query(
                                uri,
                                arrayOf(OpenableColumns.DISPLAY_NAME),
                                null, null, null
                            )?.use { c ->
                                if (c.moveToFirst()) c.getString(0) else null
                            }
                            result.success(name)
                        } catch (e: Exception) {
                            result.error("QUERY_NAME_FAIL", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            pendingResult?.success(null)
            pendingResult = null
            return
        }

        val uri = data.data!!
        // 修权限丢失:OPEN 和 SAVE 都要 takePersistableUriPermission。
        // 之前只有 REQ_OPEN 调了,saveAs(createDocument)拿到的 uri 没持久化权限,
        // App 重启后拿旧 uri 读 Download 文件直接 READ_FAIL
        // (content://com.android.providers.downloads.documents/document/N
        //  requires ACTION_OPEN_DOCUMENT or related APIs)。
        val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        when (requestCode) {
            REQ_OPEN, REQ_SAVE -> {
                try {
                    activity.contentResolver.takePersistableUriPermission(uri, flags)
                } catch (e: Exception) {
                }
                pendingResult?.success(uri.toString())
            }
        }
        pendingResult = null
    }

    /// 兜底清理:扫描 Download(MediaStore downloads),删除 displayName 以 basename
    /// 主名开头、且 size=0、且不是 basename 本身的 0B 空壳文件。
    /// 用于连点保存导致 Download 出现 (1)(2) 空壳时清理。
    private fun deleteZeroSiblings(basename: String): Int {
        if (basename.isEmpty()) return 0
        // basename 形如 "文本测试.md",取主名 "文本测试" 作为前缀。
        val prefix = basename.substringBeforeLast('.', basename)
        // MANAGE_EXTERNAL_STORAGE 授权后,app 能直接 File 操作 Download 公共目录
        // (授权前 listFiles 会 Permission denied,run-as 实测验证)。
        val dir = android.os.Environment.getExternalStoragePublicDirectory(
            android.os.Environment.DIRECTORY_DOWNLOADS
        )
        if (!dir.isDirectory) {
            android.util.Log.i("Mdeditor", "[CLEANUP] Downloads dir not accessible: $dir")
            return 0
        }
        var deleted = 0
        var matched = 0
        dir.listFiles()?.forEach { f ->
            val name = f.name
            // 只删同前缀、非 basename 本身(有内容的)、且 0B 的空壳。
            if (name != basename && name.startsWith(prefix) && f.length() == 0L) {
                matched++
                try {
                    if (f.delete()) deleted++
                } catch (e: Exception) {
                    android.util.Log.w("Mdeditor", "[CLEANUP] file delete failed for ${f.absolutePath}: ${e.message}")
                }
            }
        }
        android.util.Log.i(
            "Mdeditor",
            "[CLEANUP] basename=$basename prefix=$prefix matched=$matched deleted=$deleted"
        )
        return deleted
    }
}
