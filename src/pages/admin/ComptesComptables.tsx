import { useState, useEffect } from 'react';
import { AppLayout } from '@/components/layout/AppLayout';
import { useAuth } from '@/hooks/useAuth';
import { supabase } from '@/integrations/supabase/client';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Switch } from '@/components/ui/switch';
import { useToast } from '@/hooks/use-toast';
import { AccessDenied } from '@/components/ui/AccessDenied';
import { Plus, Pencil, BookOpen, Search, Filter } from 'lucide-react';
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter, DialogDescription,
} from '@/components/ui/dialog';
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select';
import { Badge } from '@/components/ui/badge';

interface CompteComptable {
  id: string;
  code: string;
  libelle: string;
  classe: number;
  is_active: boolean;
}

const SYSCOHADA_CLASSES: Record<number, string> = {
  1: 'Comptes de ressources durables',
  2: 'Comptes d\'actif immobilisé',
  3: 'Comptes de stocks',
  4: 'Comptes de tiers',
  5: 'Comptes de trésorerie',
  6: 'Comptes de charges',
  7: 'Comptes de produits',
};

export default function AdminComptesComptables() {
  const { isAdmin } = useAuth();
  const { toast } = useToast();
  const [comptes, setComptes] = useState<CompteComptable[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showDialog, setShowDialog] = useState(false);
  const [editing, setEditing] = useState<CompteComptable | null>(null);
  const [form, setForm] = useState({ code: '', libelle: '', classe: '6' });
  const [searchTerm, setSearchTerm] = useState('');
  const [filterClasse, setFilterClasse] = useState<string>('all');
  const [isSaving, setIsSaving] = useState(false);

  useEffect(() => {
    if (isAdmin) fetchComptes();
    else setIsLoading(false);
  }, [isAdmin]);

  const fetchComptes = async () => {
    setIsLoading(true);
    try {
      const { data, error } = await supabase
        .from('comptes_comptables')
        .select('*')
        .order('code');
      
      if (error) throw error;
      setComptes(data || []);
    } catch (error) {
      console.error('Error fetching comptes:', error);
      toast({
        title: 'Impossible de charger les comptes',
        description: 'Veuillez réessayer dans quelques instants.',
        variant: 'destructive',
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleSave = async () => {
    if (!form.code.trim() || !form.libelle.trim()) {
      toast({
        title: 'Informations incomplètes',
        description: 'Le code et le libellé sont obligatoires.',
      });
      return;
    }

    // Validate code format
    if (!/^\d+$/.test(form.code)) {
      toast({
        title: 'Format de code invalide',
        description: 'Le code comptable doit être numérique.',
      });
      return;
    }

    // Auto-detect classe from code if not matching
    const codeClasse = parseInt(form.code.charAt(0));
    if (codeClasse !== parseInt(form.classe)) {
      setForm({ ...form, classe: codeClasse.toString() });
    }

    setIsSaving(true);
    try {
      if (editing) {
        const { error } = await supabase
          .from('comptes_comptables')
          .update({
            code: form.code,
            libelle: form.libelle,
            classe: parseInt(form.classe),
          })
          .eq('id', editing.id);
        
        if (error) throw error;
        toast({ title: 'Compte mis à jour avec succès' });
      } else {
        // Check for duplicate code
        const existing = comptes.find(c => c.code === form.code);
        if (existing) {
          toast({
            title: 'Code déjà utilisé',
            description: 'Un compte avec ce code existe déjà.',
          });
          setIsSaving(false);
          return;
        }

        const { error } = await supabase
          .from('comptes_comptables')
          .insert({
            code: form.code,
            libelle: form.libelle,
            classe: parseInt(form.classe),
          });
        
        if (error) throw error;
        toast({ title: 'Compte créé avec succès' });
      }

      setShowDialog(false);
      setForm({ code: '', libelle: '', classe: '6' });
      setEditing(null);
      fetchComptes();
    } catch (error: any) {
      console.error('Error saving compte:', error);
      toast({
        title: 'Erreur lors de l\'enregistrement',
        description: error.message || 'Veuillez réessayer.',
        variant: 'destructive',
      });
    } finally {
      setIsSaving(false);
    }
  };

  const toggleActive = async (id: string, currentActive: boolean) => {
    try {
      const { error } = await supabase
        .from('comptes_comptables')
        .update({ is_active: !currentActive })
        .eq('id', id);
      
      if (error) throw error;
      
      toast({ 
        title: !currentActive ? 'Compte activé' : 'Compte désactivé',
      });
      fetchComptes();
    } catch (error) {
      console.error('Error toggling compte:', error);
      toast({
        title: 'Action non effectuée',
        description: 'Veuillez réessayer.',
        variant: 'destructive',
      });
    }
  };

  const openEdit = (compte: CompteComptable) => {
    setEditing(compte);
    setForm({
      code: compte.code,
      libelle: compte.libelle,
      classe: compte.classe.toString(),
    });
    setShowDialog(true);
  };

  const openNew = () => {
    setEditing(null);
    setForm({ code: '', libelle: '', classe: '6' });
    setShowDialog(true);
  };

  // Filter and search
  const filteredComptes = comptes.filter(compte => {
    const matchesSearch = searchTerm === '' || 
      compte.code.toLowerCase().includes(searchTerm.toLowerCase()) ||
      compte.libelle.toLowerCase().includes(searchTerm.toLowerCase());
    
    const matchesClasse = filterClasse === 'all' || compte.classe === parseInt(filterClasse);
    
    return matchesSearch && matchesClasse;
  });

  // Group by classe for display
  const groupedByClasse = filteredComptes.reduce((acc, compte) => {
    if (!acc[compte.classe]) acc[compte.classe] = [];
    acc[compte.classe].push(compte);
    return acc;
  }, {} as Record<number, CompteComptable[]>);

  const classeStats = Object.keys(SYSCOHADA_CLASSES).map(k => ({
    classe: parseInt(k),
    count: comptes.filter(c => c.classe === parseInt(k)).length,
    activeCount: comptes.filter(c => c.classe === parseInt(k) && c.is_active).length,
  }));

  if (!isAdmin) return <AppLayout><AccessDenied /></AppLayout>;

  return (
    <AppLayout>
      <div className="space-y-6">
        {/* Header */}
        <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 className="font-serif text-2xl font-bold flex items-center gap-2">
              <BookOpen className="h-6 w-6" />
              Plan comptable SYSCOHADA
            </h1>
            <p className="text-muted-foreground">
              Gérer les comptes comptables par classe
            </p>
          </div>
          <Button onClick={openNew}>
            <Plus className="mr-2 h-4 w-4" /> Nouveau compte
          </Button>
        </div>

        {/* Stats cards */}
        <div className="grid gap-4 grid-cols-2 sm:grid-cols-4 lg:grid-cols-7">
          {classeStats.map(stat => (
            <Card 
              key={stat.classe} 
              className={`cursor-pointer transition-all hover:ring-2 hover:ring-primary/50 ${filterClasse === stat.classe.toString() ? 'ring-2 ring-primary' : ''}`}
              onClick={() => setFilterClasse(filterClasse === stat.classe.toString() ? 'all' : stat.classe.toString())}
            >
              <CardContent className="pt-4 pb-3 px-3 text-center">
                <div className="text-2xl font-bold">{stat.classe}</div>
                <div className="text-xs text-muted-foreground truncate">{SYSCOHADA_CLASSES[stat.classe]?.split(' ')[2] || 'Classe'}</div>
                <Badge variant={stat.activeCount > 0 ? 'default' : 'secondary'} className="mt-1">
                  {stat.activeCount}/{stat.count}
                </Badge>
              </CardContent>
            </Card>
          ))}
        </div>

        {/* Search and filters */}
        <div className="flex flex-col gap-4 sm:flex-row">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <Input
              placeholder="Rechercher par code ou libellé..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="pl-10"
            />
          </div>
          <Select value={filterClasse} onValueChange={setFilterClasse}>
            <SelectTrigger className="w-full sm:w-[200px]">
              <Filter className="mr-2 h-4 w-4" />
              <SelectValue placeholder="Toutes les classes" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">Toutes les classes</SelectItem>
              {Object.entries(SYSCOHADA_CLASSES).map(([k, v]) => (
                <SelectItem key={k} value={k}>Classe {k}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        {/* Comptes list */}
        {isLoading ? (
          <div className="flex justify-center py-12">
            <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent" />
          </div>
        ) : filteredComptes.length === 0 ? (
          <Card>
            <CardContent className="py-12 text-center text-muted-foreground">
              {searchTerm || filterClasse !== 'all' 
                ? 'Aucun compte ne correspond à votre recherche.'
                : 'Aucun compte comptable défini. Cliquez sur "Nouveau compte" pour commencer.'}
            </CardContent>
          </Card>
        ) : (
          <div className="space-y-4">
            {Object.entries(groupedByClasse)
              .sort(([a], [b]) => parseInt(a) - parseInt(b))
              .map(([classe, comptesClasse]) => (
                <Card key={classe}>
                  <CardHeader className="pb-2">
                    <CardTitle className="text-lg flex items-center gap-2">
                      <span className="flex h-7 w-7 items-center justify-center rounded-full bg-primary/10 text-primary font-bold">
                        {classe}
                      </span>
                      {SYSCOHADA_CLASSES[parseInt(classe)] || `Classe ${classe}`}
                    </CardTitle>
                    <CardDescription>
                      {comptesClasse.length} compte{comptesClasse.length > 1 ? 's' : ''}
                    </CardDescription>
                  </CardHeader>
                  <CardContent>
                    <Table>
                      <TableHeader>
                        <TableRow>
                          <TableHead className="w-[120px]">Code</TableHead>
                          <TableHead>Libellé</TableHead>
                          <TableHead className="w-[100px] text-center">Actif</TableHead>
                          <TableHead className="w-[60px]"></TableHead>
                        </TableRow>
                      </TableHeader>
                      <TableBody>
                        {comptesClasse.map((compte) => (
                          <TableRow key={compte.id} className={!compte.is_active ? 'opacity-50' : ''}>
                            <TableCell className="font-mono font-medium">{compte.code}</TableCell>
                            <TableCell>{compte.libelle}</TableCell>
                            <TableCell className="text-center">
                              <Switch
                                checked={compte.is_active}
                                onCheckedChange={() => toggleActive(compte.id, compte.is_active)}
                              />
                            </TableCell>
                            <TableCell>
                              <Button
                                variant="ghost"
                                size="icon"
                                onClick={() => openEdit(compte)}
                              >
                                <Pencil className="h-4 w-4" />
                              </Button>
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

      {/* Dialog */}
      <Dialog open={showDialog} onOpenChange={setShowDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{editing ? 'Modifier le compte' : 'Nouveau compte comptable'}</DialogTitle>
            <DialogDescription>
              {editing 
                ? 'Modifiez les informations du compte comptable.'
                : 'Ajoutez un nouveau compte au plan comptable SYSCOHADA.'}
            </DialogDescription>
          </DialogHeader>
          
          <div className="space-y-4 py-4">
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="code">Code comptable *</Label>
                <Input
                  id="code"
                  placeholder="Ex: 601100"
                  value={form.code}
                  onChange={(e) => {
                    const newCode = e.target.value.replace(/\D/g, '');
                    const codeClasse = newCode.charAt(0);
                    setForm({ 
                      ...form, 
                      code: newCode,
                      classe: codeClasse && parseInt(codeClasse) >= 1 && parseInt(codeClasse) <= 7 
                        ? codeClasse 
                        : form.classe
                    });
                  }}
                  maxLength={10}
                />
                <p className="text-xs text-muted-foreground">
                  La classe sera détectée automatiquement
                </p>
              </div>
              
              <div className="space-y-2">
                <Label htmlFor="classe">Classe SYSCOHADA *</Label>
                <Select value={form.classe} onValueChange={(v) => setForm({ ...form, classe: v })}>
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {Object.entries(SYSCOHADA_CLASSES).map(([k, v]) => (
                      <SelectItem key={k} value={k}>
                        {k} - {v}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>
            
            <div className="space-y-2">
              <Label htmlFor="libelle">Libellé *</Label>
              <Input
                id="libelle"
                placeholder="Ex: Achats de matières premières"
                value={form.libelle}
                onChange={(e) => setForm({ ...form, libelle: e.target.value })}
                maxLength={200}
              />
            </div>
          </div>
          
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowDialog(false)}>
              Annuler
            </Button>
            <Button onClick={handleSave} disabled={isSaving}>
              {isSaving ? 'Enregistrement...' : 'Enregistrer'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </AppLayout>
  );
}
