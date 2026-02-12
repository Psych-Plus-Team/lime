package lime.system;

#if sys
import sys.io.File;
#end

/**
 * System-level RAM queries.
 *
 * Notes:
 * - On Android/Linux, reads `/proc/meminfo` and returns values in MB.
 * - This is total device RAM, not process memory.
 */
class Memory
{
	/**
	 * Total installed RAM in MB.
	 */
	public static function getTotalRAMMB():Int
	{
		#if (android || linux)
		return readMeminfoMB(true);
		#else
		return 0;
		#end
	}

	/**
	 * Available RAM in MB.
	 */
	public static function getAvailableRAMMB():Int
	{
		#if (android || linux)
		return readMeminfoMB(false);
		#else
		return 0;
		#end
	}

	#if (android || linux)
	private static function readMeminfoMB(total:Bool):Int
	{
		#if sys
		try
		{
			var content = File.getContent("/proc/meminfo");
			if (content == null || content.length == 0) return 0;

			if (total)
			{
				var reTotal:EReg = ~/^MemTotal:\s+(\d+)\s+kB/im;
				if (reTotal.match(content))
				{
					var kb = Std.parseInt(reTotal.matched(1));
					if (kb != null && kb > 0) return Std.int(kb / 1024);
				}
			}
			else
			{
				var reAvail:EReg = ~/^MemAvailable:\s+(\d+)\s+kB/im;
				if (reAvail.match(content))
				{
					var kb = Std.parseInt(reAvail.matched(1));
					if (kb != null && kb > 0) return Std.int(kb / 1024);
				}

				// Fallback (older kernels): MemFree + Buffers + Cached
				var reFree:EReg = ~/^MemFree:\s+(\d+)\s+kB/im;
				var reBuffers:EReg = ~/^Buffers:\s+(\d+)\s+kB/im;
				var reCached:EReg = ~/^Cached:\s+(\d+)\s+kB/im;
				var memFree = (reFree.match(content) ? Std.parseInt(reFree.matched(1)) : 0);
				var buffers = (reBuffers.match(content) ? Std.parseInt(reBuffers.matched(1)) : 0);
				var cached = (reCached.match(content) ? Std.parseInt(reCached.matched(1)) : 0);

				if (memFree != null && memFree > 0)
				{
					return Std.int((memFree + buffers + cached) / 1024);
				}
			}
		}
		catch (e:Dynamic)
		{
			// Keep it silent: consumers can fall back to other methods.
		}
		#end

		return 0;
	}
	#end
}
