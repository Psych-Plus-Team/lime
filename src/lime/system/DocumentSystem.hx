package lime.system;

#if (android && lime_cffi)
import lime.utils.Bytes;
import sys.FileSystem;
import sys.io.File;

#if !lime_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
class DocumentSystem {

	@:noCompletion
	private var root:String;

    public function new(treeUri:String) {
        root = treeUri;
    }

	public function writeBytes(path:String, bytes:Bytes):Void
	{
		File.saveBytes(resolve(path), bytes);
	}

	public function readBytes(path:String):Bytes
	{
		var fullPath:String = resolve(path);
		return FileSystem.exists(fullPath) ? File.getBytes(fullPath) : null;
	}

	public function saveContent(path:String, content:String):Void
	{
		writeBytes(path, Bytes.ofString(content));
	}

	public function getContent(path:String):String
	{
		var bytes = readBytes(path);
		if (bytes == null || bytes.length == 0) {
			return '';
		}
		return bytes.toString();
	}

	public function createDirectory(path:String):Void
	{
		FileSystem.createDirectory(resolve(path));
	}

	public function readDirectory(path:String):Array<String>
	{
		var fullPath:String = resolve(path);
		return FileSystem.exists(fullPath) && FileSystem.isDirectory(fullPath) ? FileSystem.readDirectory(fullPath) : [];
	}

	public function exists(path:String):Bool
	{
		return FileSystem.exists(resolve(path));
	}

	public function deleteDirectory(path:String):Bool
	{
		var fullPath:String = resolve(path);
		if (!FileSystem.exists(fullPath) || !FileSystem.isDirectory(fullPath))
			return false;
		FileSystem.deleteDirectory(fullPath);
		return true;
	}

	public function deleteFile(path:String):Bool
	{
		var fullPath:String = resolve(path);
		if (!FileSystem.exists(fullPath) || FileSystem.isDirectory(fullPath))
			return false;
		FileSystem.deleteFile(fullPath);
		return true;
	}

	public function isDirectory(path:String):Bool
	{
		var fullPath:String = resolve(path);
		return FileSystem.exists(fullPath) && FileSystem.isDirectory(fullPath);
	}

	function resolve(path:String):String
	{
		if (path == null || path.length == 0)
			return root;
		if (root == null || root.length == 0 || path.indexOf(':') >= 0 || StringTools.startsWith(path, '/') || StringTools.startsWith(path, '\\'))
			return path;
		return root + (StringTools.endsWith(root, '/') || StringTools.endsWith(root, '\\') ? '' : '/') + path;
	}
}
#end
