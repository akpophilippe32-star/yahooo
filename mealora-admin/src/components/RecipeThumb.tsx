import { useEffect, useState } from 'react';
import { PlayCircle } from 'lucide-react';
import { getRecipeImageUrl } from '../lib/adminApi';

interface RecipeThumbProps {
  imageUrl: string | null;
  isVideo: boolean;
  size?: number;
}

export default function RecipeThumb({
  imageUrl,
  isVideo,
  size = 44,
}: RecipeThumbProps) {
  const [url, setUrl] = useState<string | null>(null);

  useEffect(() => {
    if (isVideo || !imageUrl) return;

    let cancelled = false;
    getRecipeImageUrl(imageUrl).then((resolved) => {
      if (!cancelled) setUrl(resolved);
    });

    return () => {
      cancelled = true;
    };
  }, [imageUrl, isVideo]);

  if (isVideo) {
    return (
      <div
        className="recipe-thumb"
        style={{
          width: size,
          height: size,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <PlayCircle size={size * 0.4} color="var(--color-text-muted)" />
      </div>
    );
  }

  return url ? (
    <img
      src={url}
      alt=""
      className="recipe-thumb"
      style={{ width: size, height: size }}
    />
  ) : (
    <div
      className="recipe-thumb skeleton"
      style={{ width: size, height: size }}
    />
  );
}