import { useEffect, useState } from 'react';
import { User } from 'lucide-react';
import { getAvatarUrl } from '../lib/adminApi';

interface AvatarProps {
  path: string | null | undefined;
  size?: number;
}

export default function Avatar({ path, size = 40 }: AvatarProps) {
  const [url, setUrl] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    if (!path) {
      setUrl(null);
      return;
    }

    getAvatarUrl(path).then((resolved) => {
      if (!cancelled) setUrl(resolved);
    });

    return () => {
      cancelled = true;
    };
  }, [path]);

  if (url) {
    return (
      <img
        src={url}
        alt=""
        style={{
          width: size,
          height: size,
          borderRadius: '50%',
          objectFit: 'cover',
          flexShrink: 0,
        }}
      />
    );
  }

  return (
    <div
      className="avatar-fallback"
      style={{ width: size, height: size, flexShrink: 0 }}
    >
      <User size={size * 0.5} strokeWidth={1.75} />
    </div>
  );
}
