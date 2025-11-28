package com.astrbot.astrbot_android;

import android.database.Cursor;
import android.database.MatrixCursor;
import android.graphics.Point;
import android.os.CancellationSignal;
import android.os.ParcelFileDescriptor;
import android.provider.DocumentsContract;
import android.provider.DocumentsProvider;
import android.webkit.MimeTypeMap;

import androidx.annotation.Nullable;

import java.io.File;
import java.io.FileNotFoundException;
import java.util.Collections;
import java.util.LinkedList;

/**
 * Ubuntu 文件系统 DocumentsProvider
 * 将 AstrBot Ubuntu 环境暴露到系统文件管理器
 */
public class UbuntuDocumentsProvider extends DocumentsProvider {
    private static final String TAG = "UbuntuDocsProvider";
    private static final String ROOT_ID = "ubuntu_root";

    // 定义支持的列
    private static final String[] DEFAULT_ROOT_PROJECTION = new String[]{
            DocumentsContract.Root.COLUMN_ROOT_ID,
            DocumentsContract.Root.COLUMN_MIME_TYPES,
            DocumentsContract.Root.COLUMN_FLAGS,
            DocumentsContract.Root.COLUMN_ICON,
            DocumentsContract.Root.COLUMN_TITLE,
            DocumentsContract.Root.COLUMN_SUMMARY,
            DocumentsContract.Root.COLUMN_DOCUMENT_ID,
            DocumentsContract.Root.COLUMN_AVAILABLE_BYTES,
    };

    private static final String[] DEFAULT_DOCUMENT_PROJECTION = new String[]{
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
            DocumentsContract.Document.COLUMN_FLAGS,
            DocumentsContract.Document.COLUMN_SIZE,
    };

    @Override
    public boolean onCreate() {
        return true;
    }

    @Override
    public Cursor queryRoots(String[] projection) throws FileNotFoundException {
        final MatrixCursor result = new MatrixCursor(resolveRootProjection(projection));
        
        File ubuntuPath = getUbuntuRootPath();
        if (!ubuntuPath.exists()) {
            return result;
        }

        final MatrixCursor.RowBuilder row = result.newRow();
        row.add(DocumentsContract.Root.COLUMN_ROOT_ID, ROOT_ID);
        row.add(DocumentsContract.Root.COLUMN_DOCUMENT_ID, getDocIdForFile(ubuntuPath));
        row.add(DocumentsContract.Root.COLUMN_SUMMARY, "AstrBot Ubuntu 环境");
        row.add(DocumentsContract.Root.COLUMN_FLAGS,
                DocumentsContract.Root.FLAG_SUPPORTS_CREATE |
                DocumentsContract.Root.FLAG_SUPPORTS_IS_CHILD);
        row.add(DocumentsContract.Root.COLUMN_TITLE, "AstrBot Ubuntu");
        row.add(DocumentsContract.Root.COLUMN_MIME_TYPES, "*/*");
        row.add(DocumentsContract.Root.COLUMN_AVAILABLE_BYTES, ubuntuPath.getFreeSpace());
        row.add(DocumentsContract.Root.COLUMN_ICON, R.mipmap.ic_launcher);

        return result;
    }

    @Override
    public Cursor queryDocument(String documentId, String[] projection) throws FileNotFoundException {
        final MatrixCursor result = new MatrixCursor(resolveDocumentProjection(projection));
        includeFile(result, documentId, null);
        return result;
    }

    @Override
    public Cursor queryChildDocuments(String parentDocumentId, String[] projection, String sortOrder)
            throws FileNotFoundException {
        final MatrixCursor result = new MatrixCursor(resolveDocumentProjection(projection));
        final File parent = getFileForDocId(parentDocumentId);
        
        File[] files = parent.listFiles();
        if (files != null) {
            for (File file : files) {
                // 跳过符号链接指向外部的情况，避免安全检查失败
                try {
                    // 检查是否是有效的子文档
                    String childPath = file.getAbsolutePath();
                    String parentPath = parent.getAbsolutePath();
                    if (!parentPath.endsWith("/")) {
                        parentPath += "/";
                    }
                    
                    // 只包含真正的子路径
                    if (childPath.startsWith(parentPath) || childPath.equals(parent.getAbsolutePath())) {
                        includeFile(result, null, file);
                    }
                } catch (Exception e) {
                    // 跳过有问题的文件
                    continue;
                }
            }
        }
        return result;
    }

    @Override
    public ParcelFileDescriptor openDocument(String documentId, String mode, @Nullable CancellationSignal signal)
            throws FileNotFoundException {
        final File file = getFileForDocId(documentId);
        final int accessMode = ParcelFileDescriptor.parseMode(mode);
        return ParcelFileDescriptor.open(file, accessMode);
    }

    @Override
    public String createDocument(String parentDocumentId, String mimeType, String displayName)
            throws FileNotFoundException {
        File parent = getFileForDocId(parentDocumentId);
        File file = new File(parent, displayName);

        try {
            if (DocumentsContract.Document.MIME_TYPE_DIR.equals(mimeType)) {
                if (!file.mkdir()) {
                    throw new FileNotFoundException("Failed to create directory");
                }
            } else {
                if (!file.createNewFile()) {
                    throw new FileNotFoundException("Failed to create file");
                }
            }
        } catch (Exception e) {
            throw new FileNotFoundException("Failed to create document: " + e.getMessage());
        }

        return getDocIdForFile(file);
    }

    @Override
    public void deleteDocument(String documentId) throws FileNotFoundException {
        File file = getFileForDocId(documentId);
        if (!file.delete()) {
            throw new FileNotFoundException("Failed to delete document");
        }
    }

    @Override
    public String renameDocument(String documentId, String displayName) throws FileNotFoundException {
        File file = getFileForDocId(documentId);
        File target = new File(file.getParentFile(), displayName);
        
        if (!file.renameTo(target)) {
            throw new FileNotFoundException("Failed to rename document");
        }
        
        return getDocIdForFile(target);
    }

    /**
     * 获取 Ubuntu 根路径
     */
    private File getUbuntuRootPath() {
        // 获取应用的内部存储路径
        File filesDir = getContext().getFilesDir();
        return new File(filesDir, "usr/var/lib/proot-distro/installed-rootfs/ubuntu");
    }

    /**
     * 通过文档 ID 获取文件
     */
    private File getFileForDocId(String docId) throws FileNotFoundException {
        File target = new File(docId);
        if (!target.exists()) {
            throw new FileNotFoundException("File not found: " + docId);
        }
        // 不解析符号链接，直接返回
        return target;
    }
    
    /**
     * 检查文件是否是根目录的子文件
     * 覆盖此方法以正确处理符号链接
     */
    @Override
    public boolean isChildDocument(String parentDocumentId, String documentId) {
        try {
            File parent = getFileForDocId(parentDocumentId);
            File child = getFileForDocId(documentId);
            
            // 使用字符串路径比较，而不是 canonical path
            // 这样可以正确处理符号链接
            String parentPath = parent.getAbsolutePath();
            String childPath = child.getAbsolutePath();
            
            if (!parentPath.endsWith("/")) {
                parentPath += "/";
            }
            
            return childPath.startsWith(parentPath);
        } catch (FileNotFoundException e) {
            return false;
        }
    }

    /**
     * 获取文件的文档 ID（使用绝对路径）
     */
    private String getDocIdForFile(File file) {
        return file.getAbsolutePath();
    }

    /**
     * 将文件信息添加到游标
     */
    private void includeFile(MatrixCursor result, String docId, File file)
            throws FileNotFoundException {
        if (docId == null) {
            docId = getDocIdForFile(file);
        } else {
            file = getFileForDocId(docId);
        }

        int flags = 0;

        if (file.isDirectory()) {
            if (file.canWrite()) {
                flags |= DocumentsContract.Document.FLAG_DIR_SUPPORTS_CREATE;
            }
        } else if (file.canWrite()) {
            flags |= DocumentsContract.Document.FLAG_SUPPORTS_WRITE;
            flags |= DocumentsContract.Document.FLAG_SUPPORTS_DELETE;
        }

        if (file.canWrite()) {
            flags |= DocumentsContract.Document.FLAG_SUPPORTS_DELETE;
            flags |= DocumentsContract.Document.FLAG_SUPPORTS_RENAME;
        }

        final String displayName = file.getName();
        final String mimeType = getTypeForFile(file);

        if (mimeType.startsWith("image/")) {
            flags |= DocumentsContract.Document.FLAG_SUPPORTS_THUMBNAIL;
        }

        final MatrixCursor.RowBuilder row = result.newRow();
        row.add(DocumentsContract.Document.COLUMN_DOCUMENT_ID, docId);
        row.add(DocumentsContract.Document.COLUMN_DISPLAY_NAME, displayName);
        row.add(DocumentsContract.Document.COLUMN_SIZE, file.length());
        row.add(DocumentsContract.Document.COLUMN_MIME_TYPE, mimeType);
        row.add(DocumentsContract.Document.COLUMN_LAST_MODIFIED, file.lastModified());
        row.add(DocumentsContract.Document.COLUMN_FLAGS, flags);
    }

    /**
     * 根据文件获取 MIME 类型
     */
    private static String getTypeForFile(File file) {
        if (file.isDirectory()) {
            return DocumentsContract.Document.MIME_TYPE_DIR;
        } else {
            final String name = file.getName();
            final int lastDot = name.lastIndexOf('.');
            if (lastDot >= 0) {
                final String extension = name.substring(lastDot + 1).toLowerCase();
                final String mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension);
                if (mime != null) {
                    return mime;
                }
            }
            return "application/octet-stream";
        }
    }

    private static String[] resolveRootProjection(String[] projection) {
        return projection != null ? projection : DEFAULT_ROOT_PROJECTION;
    }

    private static String[] resolveDocumentProjection(String[] projection) {
        return projection != null ? projection : DEFAULT_DOCUMENT_PROJECTION;
    }
}
