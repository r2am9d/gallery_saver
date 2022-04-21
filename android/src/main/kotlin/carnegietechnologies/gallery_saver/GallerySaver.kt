package carnegietechnologies.gallery_saver

import android.Manifest
import android.app.Activity
import java.io.Serializable
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.*

enum class MediaType { image, video, file }

/**
 * Class holding implementation of saving images and videos
 */
class GallerySaver internal constructor(private val activity: Activity) :
    PluginRegistry.RequestPermissionsResultListener {

    private var pendingResult: MethodChannel.Result? = null
    private var mediaType: MediaType? = null
    private var filePath: String = ""
    private var fileName: String = ""
    private var albumName: String = ""
    private var toDcim: Boolean = false

    private val job = Job()
    private val uiScope = CoroutineScope(Dispatchers.Main + job)

    /**
     * Saves image or video to device
     *
     * @param methodCall - method call
     * @param result     - result to be set when saving operation finishes
     * @param mediaType    - media type
     */
    internal fun checkPermissionAndSaveFile(
        methodCall: MethodCall,
        result: MethodChannel.Result,
        mediaType: MediaType
    ) {
        filePath = methodCall.argument<Any>(KEY_PATH)?.toString() ?: ""
        fileName = methodCall.argument<Any>(KEY_FILE_NAME)?.toString() ?: ""
        albumName = methodCall.argument<Any>(KEY_ALBUM_NAME)?.toString() ?: ""
        toDcim = methodCall.argument<Any>(KEY_TO_DCIM) as Boolean
        this.mediaType = mediaType
        this.pendingResult = result

        if (isWritePermissionGranted() || android.os.Build.VERSION.SDK_INT >= 29) {
            saveMediaFile()
        } else {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                REQUEST_EXTERNAL_IMAGE_STORAGE_PERMISSION
            )
        }
    }

    internal fun deleteFile(
        methodCall: MethodCall,
        result: MethodChannel.Result,
        mediaType: MediaType
    ) {
        filePath = methodCall.argument<Any>(KEY_PATH)?.toString() ?: ""
        this.mediaType = mediaType
        this.pendingResult = result

        if (isWritePermissionGranted() || android.os.Build.VERSION.SDK_INT >= 29) {
            deleteMediaFile()
        } else {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                REQUEST_EXTERNAL_IMAGE_STORAGE_PERMISSION
            )
        }
    }

    private fun deleteMediaFile() {
        uiScope.launch {
            val result = async(Dispatchers.IO) {
                if (mediaType == MediaType.video) {
                    FileUtils.deleteVideo(activity.contentResolver, filePath);
                } else if (mediaType == MediaType.image) {
                    FileUtils.deleteImage(activity.contentResolver, filePath);
                } else {
                    FileUtils.deleteFile(activity.contentResolver, filePath);
                }
            }.await();
            finishWithSuccess(result);
        }
    }

    private fun isWritePermissionGranted(): Boolean {
        return PackageManager.PERMISSION_GRANTED ==
                ActivityCompat.checkSelfPermission(
                    activity, Manifest.permission.WRITE_EXTERNAL_STORAGE
                )
    }

    private fun saveMediaFile() {
        uiScope.launch {
            val result = async(Dispatchers.IO) {
                if (mediaType == MediaType.video) {
                    FileUtils.insertVideo(activity.contentResolver, filePath, fileName, albumName, toDcim);
                } else if (mediaType == MediaType.image) {
                    FileUtils.insertImage(activity.contentResolver, filePath, fileName, albumName, toDcim);
                } else {
                    FileUtils.insertFile(activity.contentResolver, filePath, fileName, albumName, toDcim);
                }
            }.await();
            finishWithSuccess(result);
        }
    }

    private fun finishWithSuccess(result: Serializable) {
        pendingResult!!.success(result);
        pendingResult = null;
    }

    private fun finishWithFailure() {
        pendingResult!!.success(false);
        pendingResult = null;
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<String>, grantResults: IntArray
    ): Boolean {
        if (requestCode == REQUEST_EXTERNAL_IMAGE_STORAGE_PERMISSION) {
            val permissionGranted = grantResults.isNotEmpty()
                    && grantResults[0] == PackageManager.PERMISSION_GRANTED
            if (permissionGranted) {
                saveMediaFile()
            } else {
                finishWithFailure()
            }
            return true
        }
        return false
    }

    companion object {

        private const val REQUEST_EXTERNAL_IMAGE_STORAGE_PERMISSION = 2408

        private const val KEY_PATH = "path"
        private const val KEY_FILE_NAME = "fileName"
        private const val KEY_ALBUM_NAME = "albumName"
        private const val KEY_TO_DCIM = "toDcim"
    }
}
