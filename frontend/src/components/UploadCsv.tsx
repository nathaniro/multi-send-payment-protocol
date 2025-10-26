import Papa from 'papaparse';
import { ChangeEvent } from 'react';

interface Recipient { address: string; amount?: number; }
function UploadCsv({ onUpload }: { onUpload: (list: Recipient[]) => void }) {
  const handleUpload = (e: ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    Papa.parse(file, {
      header: true,
      complete: (results) => {
        const list = results.data as Recipient[];
        onUpload(list);
      }
    });
  };
  return <input type="file" accept=".csv" onChange={handleUpload} />;
}
export default UploadCsv;
