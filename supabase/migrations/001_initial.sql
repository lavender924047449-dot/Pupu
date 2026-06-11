-- Pupu MVP - 初始表结构
-- 云端备份：user_backups 存储用户完整数据 JSON
-- Storage：private-attachments 私人空间附件

-- user_backups: 每用户一份备份
CREATE TABLE IF NOT EXISTS user_backups (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  data JSONB NOT NULL DEFAULT '{}',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- RLS: 用户只能访问自己的备份
ALTER TABLE user_backups ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own backup"
  ON user_backups
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Storage bucket: private-attachments（在 Dashboard 创建或通过 API）
-- RLS policy for storage.objects（用户只能访问自己路径下的文件）:
-- CREATE POLICY "Users can manage own attachments"
-- ON storage.objects FOR ALL
-- USING ( (storage.foldername(name))[1] = auth.uid()::text )
-- WITH CHECK ( (storage.foldername(name))[1] = auth.uid()::text );
