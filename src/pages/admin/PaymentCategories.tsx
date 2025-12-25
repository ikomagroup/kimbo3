import { useState, useEffect } from 'react';
import { AppLayout } from '@/components/layout/AppLayout';
import { useAuth } from '@/hooks/useAuth';
import { supabase } from '@/integrations/supabase/client';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Switch } from '@/components/ui/switch';
import { useToast } from '@/hooks/use-toast';
import { AccessDenied } from '@/components/ui/AccessDenied';
import { Plus, Pencil, Trash2, Wallet, GripVertical } from 'lucide-react';
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter,
} from '@/components/ui/dialog';
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';

interface PaymentCategory {
  id: string;
  code: string;
  label: string;
  is_active: boolean;
  sort_order: number;
}

interface PaymentMethod {
  id: string;
  code: string;
  label: string;
  category_id: string;
  is_active: boolean;
  sort_order: number;
}

export default function AdminPaymentCategories() {
  const { isAdmin } = useAuth();
  const { toast } = useToast();
  const [categories, setCategories] = useState<PaymentCategory[]>([]);
  const [methods, setMethods] = useState<PaymentMethod[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showCatDialog, setShowCatDialog] = useState(false);
  const [showMethodDialog, setShowMethodDialog] = useState(false);
  const [editingCat, setEditingCat] = useState<PaymentCategory | null>(null);
  const [editingMethod, setEditingMethod] = useState<PaymentMethod | null>(null);
  const [selectedCatId, setSelectedCatId] = useState<string | null>(null);
  const [catForm, setCatForm] = useState({ code: '', label: '' });
  const [methodForm, setMethodForm] = useState({ code: '', label: '' });

  useEffect(() => {
    if (isAdmin) fetchData();
    else setIsLoading(false);
  }, [isAdmin]);

  const fetchData = async () => {
    setIsLoading(true);
    const [catRes, methRes] = await Promise.all([
      supabase.from('payment_categories').select('*').order('sort_order'),
      supabase.from('payment_methods').select('*').order('sort_order'),
    ]);
    if (catRes.data) setCategories(catRes.data);
    if (methRes.data) setMethods(methRes.data);
    setIsLoading(false);
  };

  const handleSaveCat = async () => {
    if (!catForm.code.trim() || !catForm.label.trim()) return;
    if (editingCat) {
      await supabase.from('payment_categories').update({
        code: catForm.code, label: catForm.label,
      }).eq('id', editingCat.id);
    } else {
      await supabase.from('payment_categories').insert({
        code: catForm.code, label: catForm.label, sort_order: categories.length + 1,
      });
    }
    toast({ title: 'Catégorie enregistrée' });
    setShowCatDialog(false);
    setCatForm({ code: '', label: '' });
    setEditingCat(null);
    fetchData();
  };

  const handleSaveMethod = async () => {
    if (!methodForm.code.trim() || !methodForm.label.trim() || !selectedCatId) return;
    if (editingMethod) {
      await supabase.from('payment_methods').update({
        code: methodForm.code, label: methodForm.label,
      }).eq('id', editingMethod.id);
    } else {
      await supabase.from('payment_methods').insert({
        code: methodForm.code, label: methodForm.label, category_id: selectedCatId,
        sort_order: methods.filter(m => m.category_id === selectedCatId).length + 1,
      });
    }
    toast({ title: 'Méthode enregistrée' });
    setShowMethodDialog(false);
    setMethodForm({ code: '', label: '' });
    setEditingMethod(null);
    fetchData();
  };

  const toggleActive = async (type: 'cat' | 'method', id: string, current: boolean) => {
    if (type === 'cat') {
      await supabase.from('payment_categories').update({ is_active: !current }).eq('id', id);
    } else {
      await supabase.from('payment_methods').update({ is_active: !current }).eq('id', id);
    }
    fetchData();
  };

  if (!isAdmin) return <AppLayout><AccessDenied /></AppLayout>;

  return (
    <AppLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="font-serif text-2xl font-bold">Modes de paiement</h1>
            <p className="text-muted-foreground">Gérer les catégories et méthodes de paiement</p>
          </div>
          <Button onClick={() => { setEditingCat(null); setCatForm({ code: '', label: '' }); setShowCatDialog(true); }}>
            <Plus className="mr-2 h-4 w-4" /> Catégorie
          </Button>
        </div>

        {isLoading ? (
          <div className="flex justify-center py-12">
            <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent" />
          </div>
        ) : (
          <div className="grid gap-4 md:grid-cols-2">
            {categories.map((cat) => (
              <Card key={cat.id}>
                <CardHeader className="flex flex-row items-center justify-between pb-2">
                  <CardTitle className="flex items-center gap-2 text-lg">
                    <Wallet className="h-5 w-5" />
                    {cat.label}
                  </CardTitle>
                  <div className="flex items-center gap-2">
                    <Switch checked={cat.is_active} onCheckedChange={() => toggleActive('cat', cat.id, cat.is_active)} />
                    <Button variant="ghost" size="icon" onClick={() => {
                      setEditingCat(cat); setCatForm({ code: cat.code, label: cat.label }); setShowCatDialog(true);
                    }}><Pencil className="h-4 w-4" /></Button>
                  </div>
                </CardHeader>
                <CardContent>
                  <div className="mb-2 flex justify-between">
                    <span className="text-sm text-muted-foreground">Code: {cat.code}</span>
                    <Button variant="outline" size="sm" onClick={() => {
                      setSelectedCatId(cat.id); setEditingMethod(null); setMethodForm({ code: '', label: '' }); setShowMethodDialog(true);
                    }}><Plus className="mr-1 h-3 w-3" /> Méthode</Button>
                  </div>
                  <Table>
                    <TableBody>
                      {methods.filter(m => m.category_id === cat.id).map((m) => (
                        <TableRow key={m.id}>
                          <TableCell className="py-1">{m.label}</TableCell>
                          <TableCell className="py-1 text-right">
                            <Switch checked={m.is_active} onCheckedChange={() => toggleActive('method', m.id, m.is_active)} />
                            <Button variant="ghost" size="icon" className="h-7 w-7" onClick={() => {
                              setSelectedCatId(cat.id); setEditingMethod(m); setMethodForm({ code: m.code, label: m.label }); setShowMethodDialog(true);
                            }}><Pencil className="h-3 w-3" /></Button>
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </CardContent>
              </Card>
            ))}
          </div>
        )}
      </div>

      <Dialog open={showCatDialog} onOpenChange={setShowCatDialog}>
        <DialogContent>
          <DialogHeader><DialogTitle>{editingCat ? 'Modifier' : 'Nouvelle'} catégorie</DialogTitle></DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2"><Label>Code</Label><Input value={catForm.code} onChange={e => setCatForm({ ...catForm, code: e.target.value })} /></div>
            <div className="space-y-2"><Label>Libellé</Label><Input value={catForm.label} onChange={e => setCatForm({ ...catForm, label: e.target.value })} /></div>
          </div>
          <DialogFooter><Button onClick={handleSaveCat}>Enregistrer</Button></DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={showMethodDialog} onOpenChange={setShowMethodDialog}>
        <DialogContent>
          <DialogHeader><DialogTitle>{editingMethod ? 'Modifier' : 'Nouvelle'} méthode</DialogTitle></DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2"><Label>Code</Label><Input value={methodForm.code} onChange={e => setMethodForm({ ...methodForm, code: e.target.value })} /></div>
            <div className="space-y-2"><Label>Libellé</Label><Input value={methodForm.label} onChange={e => setMethodForm({ ...methodForm, label: e.target.value })} /></div>
          </div>
          <DialogFooter><Button onClick={handleSaveMethod}>Enregistrer</Button></DialogFooter>
        </DialogContent>
      </Dialog>
    </AppLayout>
  );
}
