package lime._internal.backend.native;

#if sys
import sys.thread.Mutex;
#end

/** Serializes streamed OpenAL buffer work with device reopen operations. */
class AudioDeviceLock
{
	#if sys
	private static var mutex:Mutex = new Mutex();
	#end

	public static function acquire():Void
	{
		#if sys
		mutex.acquire();
		#end
	}

	public static function release():Void
	{
		#if sys
		mutex.release();
		#end
	}
}
