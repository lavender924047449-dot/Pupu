-- 私人空间附件 Storage
-- 在 Supabase Dashboard 创建 bucket 或通过 API
-- 此处为 RLS policy 示例

-- 注意：bucket 需在 Dashboard 创建，名称为 private-attachments
-- 以下 policy 需在 Supabase SQL Editor 中执行

-- CREATE POLICY "Users can manage own attachments"
-- ON storage.objects FOR ALL
-- USING ( (storage.foldername(name))[1] = auth.uid()::text )
-- WITH CHECK ( (storage.foldername(name))[1] = auth.uid()::text );
