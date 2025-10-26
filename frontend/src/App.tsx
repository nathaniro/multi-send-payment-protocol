import { useState } from 'react';
import UploadCsv from './components/UploadCsv';
import RecipientTable from './components/RecipientTable';
import SendForm from './components/SendForm';
import NetworkBadge from './components/NetworkBadge';

function App() {
  const [recipients, setRecipients] = useState<{ address: string; amount?: number }[]>([]);
  return (
    <div className="max-w-2xl mx-auto p-4 space-y-4">
      <h1 className="text-xl font-bold">Multi-Send Payment Protocol</h1>
      <NetworkBadge />
      <UploadCsv onUpload={setRecipients} />
      <RecipientTable recipients={recipients} />
      <SendForm recipients={recipients} />
    </div>
  );
}
export default App;
